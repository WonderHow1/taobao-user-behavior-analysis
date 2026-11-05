#!/usr/bin/env python3
"""Recompute the Taobao portfolio from a local source CSV or ZIP.

Only aggregate CSV/JSON files are exported. User-level working tables remain in
an explicitly chosen local DuckDB database and are not meant for publication.
"""
from argparse import ArgumentParser
from datetime import datetime, timedelta, timezone
from decimal import Decimal
from pathlib import Path
import csv
import hashlib
import json
import re
import shutil
import time
import zipfile

START = int(datetime(2017, 11, 25, tzinfo=timezone(timedelta(hours=8))).timestamp())
END = START + 9 * 86400
SCHEMA_VERSION = "taobao-portfolio-v1"
REFERENCE_COUNTS = {"pv": 89660668, "fav": 2888258, "cart": 5530445, "buy": 2015807}


def arguments():
    parser = ArgumentParser(description=__doc__)
    parser.add_argument("--source", required=True, type=Path, help="Local headerless UserBehavior.csv or a ZIP containing it")
    parser.add_argument("--output", type=Path, default=Path("results/recomputed"), help="Directory for aggregate CSV/JSON files")
    parser.add_argument("--database", type=Path, help="Local working database; default: OUTPUT/recomputed.duckdb")
    parser.add_argument("--memory-limit", default="2GB", help="DuckDB memory cap, e.g. 2GB or 4GB")
    parser.add_argument("--threads", type=int, default=4, help="DuckDB worker threads")
    parser.add_argument("--resume", action="store_true", help="Reuse a matching working database from the same source and script version")
    parser.add_argument("--verify-reference", action="store_true", help="Also require the exact four behavior totals of the full portfolio dataset")
    args = parser.parse_args()
    if args.threads < 1:
        parser.error("--threads must be positive")
    if not re.fullmatch(r"[1-9][0-9]*(?:\.[0-9]+)?(?:KB|MB|GB|TB)", args.memory_limit, flags=re.I):
        parser.error("--memory-limit must be a positive quantity such as 2GB")
    args.source = args.source.expanduser().resolve()
    args.output = args.output.expanduser().resolve()
    args.database = (args.database or args.output / "recomputed.duckdb").expanduser().resolve()
    if not args.source.is_file():
        parser.error("--source must be an existing local file")
    if args.database == args.source:
        parser.error("--database cannot be the source file")
    if args.database.exists() and not args.resume:
        parser.error("Working database already exists; use --resume or choose a new --database")
    return args


def sql_literal(value):
    return "'" + str(value).replace("'", "''") + "'"


def source_digest(source):
    digest = hashlib.sha256()
    with source.open("rb") as handle:
        for block in iter(lambda: handle.read(8 * 1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def normalize(value):
    if isinstance(value, Decimal):
        return float(value)
    if hasattr(value, "isoformat"):
        return value.isoformat()
    return value


def save_json(path, value):
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    temporary.replace(path)


def main():
    args = arguments()
    try:
        import duckdb
    except ImportError as exc:
        raise SystemExit("Install the project dependency first: python -m pip install -r requirements.txt") from exc
    args.output.mkdir(parents=True, exist_ok=True)
    args.database.parent.mkdir(parents=True, exist_ok=True)
    temporary_dir = args.database.parent / (args.database.name + ".tmp")
    temporary_dir.mkdir(exist_ok=True)
    t0 = time.monotonic()

    def log(message):
        print(f"[{time.monotonic()-t0:.1f}s] {message}", flush=True)

    log("Hashing source for safe resumption")
    digest = source_digest(args.source)
    database_existed = args.database.exists()
    con = duckdb.connect(str(args.database))
    try:
        con.execute("SET memory_limit=" + sql_literal(args.memory_limit))
        con.execute(f"SET threads={args.threads}")
        con.execute("SET preserve_insertion_order=false")
        con.execute("SET temp_directory=" + sql_literal(temporary_dir))
        if database_existed:
            has_metadata=con.execute("SELECT COUNT(*) FROM information_schema.tables WHERE table_name='analysis_metadata'").fetchone()[0]
            if not has_metadata:
                raise RuntimeError("Existing database was not created by this script. Choose a new --database.")
        con.execute("CREATE TABLE IF NOT EXISTS analysis_metadata (key VARCHAR PRIMARY KEY, value VARCHAR)")

        def meta_get(key):
            row=con.execute("SELECT value FROM analysis_metadata WHERE key=?", [key]).fetchone()
            return row[0] if row else None

        def meta_set(key, value):
            con.execute("INSERT OR REPLACE INTO analysis_metadata VALUES (?,?)", [key, value])

        expected_run = json.dumps({"source_sha256": digest, "schema_version": SCHEMA_VERSION}, sort_keys=True)
        prior_run = meta_get("run")
        if prior_run is not None and prior_run != expected_run:
            raise RuntimeError("Existing database belongs to a different source or script version. Choose a new --database.")
        if database_existed and prior_run is None:
            raise RuntimeError("Existing database has no matching run metadata. Choose a new --database.")
        if prior_run is None:
            meta_set("run", expected_run)

        def exists(name):
            return bool(con.execute("SELECT COUNT(*) FROM information_schema.tables WHERE table_name=?", [name]).fetchone()[0])

        def build(name, sql):
            if exists(name):
                log(f"Reusing {name}")
            else:
                log(f"Building {name}")
                con.execute(f"CREATE TABLE {name} AS {sql}")
                con.execute("CHECKPOINT")

        cached_quality = meta_get("quality")
        if cached_quality is not None and exists("behavior"):
            quality=json.loads(cached_quality)
            log(f"Reusing {quality['clean_rows']:,} clean records")
        else:
            extracted = args.database.parent / (args.database.name + ".source.csv")
            if not exists("raw_behavior"):
                csv_source = args.source
                try:
                    if zipfile.is_zipfile(args.source):
                        log("Extracting a disposable CSV working copy")
                        with zipfile.ZipFile(args.source) as archive:
                            names=[n for n in archive.namelist() if Path(n).name == "UserBehavior.csv"]
                            if len(names) != 1:
                                names=[n for n in archive.namelist() if n.lower().endswith(".csv") and not n.startswith("__MACOSX/")]
                            if len(names) != 1:
                                raise ValueError("ZIP must contain exactly one UserBehavior.csv (or one unambiguous CSV)")
                            with archive.open(names[0]) as source, extracted.open("wb") as target:
                                shutil.copyfileobj(source,target,length=8*1024*1024)
                        csv_source=extracted
                    log("Importing source with original row numbers")
                    con.execute("SET preserve_insertion_order=true")
                    con.execute("""CREATE TABLE raw_behavior AS
                        SELECT ROW_NUMBER() OVER() AS source_id,user_id,item_id,category_id,
                            CASE behavior_type WHEN 'pv' THEN 1 WHEN 'fav' THEN 2 WHEN 'cart' THEN 4 WHEN 'buy' THEN 8 END::UTINYINT AS behavior,timestamps
                        FROM read_csv("""+sql_literal(csv_source)+""",header=false,parallel=false,
                            columns={'user_id':'INTEGER','item_id':'INTEGER','category_id':'INTEGER','behavior_type':'VARCHAR','timestamps':'BIGINT'})""")
                    con.execute("CHECKPOINT")
                finally:
                    con.execute("SET preserve_insertion_order=false")
                    if extracted.exists():
                        extracted.unlink()
            quality={"source_zip": args.source.name, "source_sha256":digest,"timezone":"Asia/Shanghai","start_inclusive":"2017-11-25 00:00:00","end_exclusive":"2017-12-04 00:00:00"}
            quality['raw_rows'], quality['null_cells'] = con.execute("SELECT COUNT(*),COALESCE(SUM((user_id IS NULL)::INT+(item_id IS NULL)::INT+(category_id IS NULL)::INT+(behavior IS NULL)::INT+(timestamps IS NULL)::INT),0) FROM raw_behavior").fetchone()
            if not quality['raw_rows']:
                raise RuntimeError("Source is empty")
            if quality['null_cells']:
                raise RuntimeError("Source contains missing or unrecognized values; inspect before analysis")
            quality['out_of_window_after_dedup'] = con.execute(f"SELECT COUNT(*) FROM (SELECT DISTINCT user_id,item_id,timestamps FROM raw_behavior WHERE timestamps<{START} OR timestamps>={END})").fetchone()[0]
            if not exists('behavior'):
                log("Applying exact global deduplication and the nine-day window")
                con.execute(f"""CREATE TABLE behavior AS
                    SELECT user_id,item_id,category_id,behavior,timestamps,
                        ((timestamps-{START})//86400)::UTINYINT AS day,
                        (((timestamps-{START})%86400)//3600)::UTINYINT AS hour
                    FROM raw_behavior WHERE timestamps>={START} AND timestamps<{END}
                    QUALIFY ROW_NUMBER() OVER(PARTITION BY user_id,item_id,timestamps ORDER BY source_id)=1""")
            quality['clean_rows']=con.execute("SELECT COUNT(*) FROM behavior").fetchone()[0]
            quality['duplicate_rows_removed']=quality['raw_rows']-quality['out_of_window_after_dedup']-quality['clean_rows']
            if not quality['clean_rows']:
                raise RuntimeError("No source records fall inside the analysis window")
            assert quality['raw_rows']==quality['duplicate_rows_removed']+quality['out_of_window_after_dedup']+quality['clean_rows']
            meta_set("quality",json.dumps(quality))
            con.execute("DROP TABLE raw_behavior")
            con.execute("CHECKPOINT")
            log(f"Prepared {quality['clean_rows']:,} clean records")
        save_json(args.output/'quality.json',quality)
        build('user_day', '''
            SELECT user_id, day, COUNT(*) AS events,
                   COUNT(*) FILTER (WHERE behavior=1) AS pv,
                   COUNT(*) FILTER (WHERE behavior=2) AS fav,
                   COUNT(*) FILTER (WHERE behavior=4) AS cart,
                   COUNT(*) FILTER (WHERE behavior=8) AS buy
            FROM behavior GROUP BY user_id, day
        ''')
        build('user_summary', '''
            SELECT user_id, SUM(events) AS events, SUM(pv) AS pv, SUM(fav) AS fav,
                   SUM(cart) AS cart, SUM(buy) AS buy,
                   BIT_OR(1::INTEGER << day) AS active_days,
                   COUNT(*) AS active_day_count,
                   MAX(day) FILTER (WHERE buy>0) AS last_buy_day
            FROM user_day GROUP BY user_id
        ''')
        build('rf_scores', '''
            SELECT *, CASE WHEN last_buy_day=8 THEN 5 WHEN last_buy_day IN (6,7) THEN 4
                      WHEN last_buy_day IN (4,5) THEN 3 WHEN last_buy_day IN (2,3) THEN 2 ELSE 1 END AS r_score,
                   NTILE(5) OVER (ORDER BY buy, user_id) AS f_score
            FROM user_summary WHERE buy>0
        ''')
        build('bought_pairs', '''SELECT user_id,item_id,COUNT(*) AS buy_events FROM behavior WHERE behavior=8 GROUP BY user_id,item_id''')
        build('buy_paths', '''
            SELECT b.user_id,b.item_id, BIT_OR(b.behavior) AS flags,
                   COUNT(*) FILTER (WHERE b.behavior=8) AS buy_events,
                   MIN(b.timestamps) FILTER (WHERE b.behavior=1) AS first_pv,
                   MIN(b.timestamps) FILTER (WHERE b.behavior IN (2,4)) AS first_intent,
                   MIN(b.timestamps) FILTER (WHERE b.behavior=8) AS first_buy
            FROM behavior b SEMI JOIN bought_pairs p USING(user_id,item_id)
            GROUP BY b.user_id,b.item_id
        ''')
        build('item_summary', '''
            SELECT item_id, MIN(category_id) AS category_id,
                   COUNT(*) FILTER (WHERE behavior=1) AS pv,
                   COUNT(*) FILTER (WHERE behavior=2) AS fav,
                   COUNT(*) FILTER (WHERE behavior=4) AS cart,
                   COUNT(*) FILTER (WHERE behavior=8) AS buy,
                   COUNT(DISTINCT user_id) AS users,
                   COUNT(DISTINCT user_id) FILTER (WHERE behavior=8) AS buyers,
                   COUNT(DISTINCT category_id) AS category_count
            FROM behavior GROUP BY item_id
        ''')
        build('category_summary', '''
            SELECT category_id, COUNT(*) FILTER (WHERE behavior=1) AS pv,
                   COUNT(*) FILTER (WHERE behavior=2) AS fav,
                   COUNT(*) FILTER (WHERE behavior=4) AS cart,
                   COUNT(*) FILTER (WHERE behavior=8) AS buy,
                   COUNT(DISTINCT user_id) AS users,
                   COUNT(DISTINCT user_id) FILTER (WHERE behavior=8) AS buyers,
                   COUNT(DISTINCT item_id) AS items
            FROM behavior GROUP BY category_id
        ''')
        build('category_item_summary', '''
            SELECT category_id,item_id,COUNT(*) FILTER(WHERE behavior=1) AS pv,
                   COUNT(*) FILTER(WHERE behavior=2) AS fav,
                   COUNT(*) FILTER(WHERE behavior=4) AS cart,
                   COUNT(*) FILTER(WHERE behavior=8) AS buy
            FROM behavior GROUP BY category_id,item_id
        ''')

        queries = {
            'overview': '''SELECT COUNT(*) AS users, SUM(events) AS events, SUM(pv) AS pv, SUM(fav) AS fav, SUM(cart) AS cart, SUM(buy) AS buy, COUNT(*) FILTER(WHERE pv>0) AS pv_users, COUNT(*) FILTER(WHERE fav>0) AS fav_users, COUNT(*) FILTER(WHERE cart>0) AS cart_users, COUNT(*) FILTER(WHERE buy>0) AS buyers, COUNT(*) FILTER(WHERE buy=0) AS nonbuyers, COUNT(*) FILTER(WHERE buy>=2) AS repeat_buyers, COUNT(*) FILTER(WHERE events=1) AS single_event_users, AVG(active_day_count) AS average_active_days FROM user_summary''',
            'daily': '''SELECT DATE '2017-11-25' + day::INTEGER AS date, SUM(pv) AS pv, COUNT(*) FILTER(WHERE pv>0) AS uv, SUM(pv)/NULLIF(COUNT(*) FILTER(WHERE pv>0),0) AS browsing_depth, SUM(fav) AS fav, SUM(cart) AS cart, SUM(buy) AS buy, COUNT(*) AS active_users, COUNT(*) FILTER(WHERE buy>0) AS buyers, SUM(buy)/NULLIF(SUM(pv),0) AS buy_event_pv_ratio FROM user_day GROUP BY day ORDER BY day''',
            'hourly': '''SELECT hour, COUNT(*) FILTER(WHERE behavior=1) AS pv, COUNT(*) FILTER(WHERE behavior=2) AS fav, COUNT(*) FILTER(WHERE behavior=4) AS cart, COUNT(*) FILTER(WHERE behavior=8) AS buy FROM behavior GROUP BY hour ORDER BY hour''',
            'date_hour': '''SELECT DATE '2017-11-25'+day::INTEGER AS date,hour, COUNT(*) FILTER(WHERE behavior=1) AS pv, COUNT(*) FILTER(WHERE behavior=2) AS fav, COUNT(*) FILTER(WHERE behavior=4) AS cart, COUNT(*) FILTER(WHERE behavior=8) AS buy FROM behavior GROUP BY day,hour ORDER BY day,hour''',
            'retention': '''SELECT DATE '2017-11-25'+d::INTEGER AS date, COUNT(*) FILTER(WHERE active_days & (1<<d) >0) AS active_users, CASE WHEN d<8 THEN COUNT(*) FILTER(WHERE active_days & (1<<d)>0 AND active_days & (1<<(d+1))>0) END AS day1_users, CASE WHEN d<8 THEN COUNT(*) FILTER(WHERE active_days & (1<<d)>0 AND active_days & (1<<(d+1))>0)*1.0/NULLIF(COUNT(*) FILTER(WHERE active_days & (1<<d)>0),0) END AS day1_retention, CASE WHEN d<2 THEN COUNT(*) FILTER(WHERE active_days & (1<<d)>0 AND active_days & (1<<(d+7))>0)*1.0/NULLIF(COUNT(*) FILTER(WHERE active_days & (1<<d)>0),0) END AS day7_retention FROM user_summary CROSS JOIN range(9) t(d) GROUP BY d ORDER BY d''',
            'funnel': '''SELECT COUNT(*) FILTER(WHERE pv>0) AS browsing_users, COUNT(*) FILTER(WHERE pv>0 AND (fav>0 OR cart>0)) AS intent_users, COUNT(*) FILTER(WHERE pv>0 AND (fav>0 OR cart>0) AND buy>0) AS funnel_buyers, COUNT(*) FILTER(WHERE pv>0 AND buy>0) AS browsing_buyers, COUNT(*) FILTER(WHERE pv>0 AND fav=0 AND cart=0 AND buy>0) AS browsing_buyers_without_intent FROM user_summary''',
            'user_intent_groups': '''SELECT fav>0 AS has_fav,cart>0 AS has_cart, COUNT(*) AS users, COUNT(*) FILTER(WHERE buy>0) AS buyers, COUNT(*) FILTER(WHERE buy>0)*1.0/COUNT(*) AS buying_user_share FROM user_summary WHERE pv>0 GROUP BY 1,2 ORDER BY 1,2''',
            'paths': '''SELECT flags, COUNT(*) AS user_item_pairs, SUM(buy_events) AS buy_events, COUNT(*) FILTER(WHERE first_pv<=first_buy) AS pv_before_or_at_first_buy_pairs, COUNT(*) FILTER(WHERE first_intent<=first_buy) AS intent_before_or_at_first_buy_pairs FROM buy_paths GROUP BY flags ORDER BY user_item_pairs DESC''',
            'rf_classes': '''WITH a AS(SELECT AVG(r_score) r_avg,AVG(f_score) f_avg FROM rf_scores) SELECT CASE WHEN r_score>r_avg AND f_score>f_avg THEN '价值用户' WHEN r_score>r_avg AND f_score<f_avg THEN '发展用户' WHEN r_score<r_avg AND f_score>f_avg THEN '保持用户' WHEN r_score<r_avg AND f_score<f_avg THEN '挽留用户' ELSE '等于均值未分类' END AS class, COUNT(*) AS users, SUM(buy) AS buy_events,AVG(buy) AS average_buys FROM rf_scores CROSS JOIN a GROUP BY 1 ORDER BY users DESC''',
            'rf_score_distribution': '''SELECT f_score, COUNT(*) AS users, MIN(buy) AS min_buys,MAX(buy) AS max_buys FROM rf_scores GROUP BY f_score ORDER BY f_score''',
            'purchase_frequency': '''SELECT buy AS purchases,COUNT(*) AS users FROM user_summary WHERE buy>0 GROUP BY buy ORDER BY buy''',
            'top_categories': '''SELECT *, buyers*1.0/users AS buyer_share, buy*1.0/NULLIF(pv,0) AS buy_event_pv_ratio FROM category_summary ORDER BY pv DESC LIMIT 20''',
            'top_items': '''SELECT *, buyers*1.0/users AS buyer_share, buy*1.0/NULLIF(pv,0) AS buy_event_pv_ratio FROM item_summary ORDER BY pv DESC LIMIT 20''',
            'top_bought_categories': '''SELECT *,buyers*1.0/users AS buyer_share FROM category_summary ORDER BY buy DESC LIMIT 20''',
            'top_bought_items': '''SELECT *,buyers*1.0/users AS buyer_share FROM item_summary ORDER BY buy DESC LIMIT 20''',
            'category_top_items': '''SELECT * FROM category_item_summary QUALIFY RANK() OVER(PARTITION BY category_id ORDER BY pv DESC)=1 ORDER BY pv DESC LIMIT 20''',
            'item_conversion_min100': '''SELECT *,buyers*1.0/users AS buyer_share FROM item_summary WHERE users>=100 ORDER BY buyer_share DESC,users DESC LIMIT 20''',
            'category_conversion_min1000': '''SELECT *,buyers*1.0/users AS buyer_share FROM category_summary WHERE users>=1000 ORDER BY buyer_share DESC,users DESC LIMIT 20''',
            'goods_overview': '''SELECT (SELECT COUNT(*) FROM item_summary) AS items,(SELECT COUNT(*) FROM category_summary) AS categories,COUNT(*) FILTER(WHERE buy>0) AS items_with_purchase, COUNT(*) FILTER(WHERE pv>0 AND buy=0) AS viewed_items_without_purchase,COUNT(*) FILTER(WHERE pv=0 AND buy>0) AS bought_items_without_pv,COUNT(*) FILTER(WHERE category_count>1) AS multi_category_items,CORR(pv,buy) AS pearson_item_pv_buy, SUM(pv) FILTER(WHERE pv=0) AS pv_zero_total FROM item_summary''',
            'item_matrix': '''WITH a AS(SELECT AVG(pv) AS pv_avg,AVG(buy) AS buy_avg FROM item_summary) SELECT CASE WHEN pv>=pv_avg AND buy>=buy_avg THEN '高浏览高购买' WHEN pv>=pv_avg AND buy<buy_avg THEN '高浏览低购买' WHEN pv<pv_avg AND buy>=buy_avg THEN '低浏览高购买' ELSE '低浏览低购买' END AS quadrant,COUNT(*) AS items,SUM(pv) AS pv,SUM(buy) AS buy FROM item_summary CROSS JOIN a GROUP BY 1''',
            'top20_concentration': '''SELECT (SELECT SUM(pv) FROM (SELECT pv FROM category_summary ORDER BY pv DESC LIMIT 20)) AS top20_category_pv,(SELECT SUM(pv) FROM (SELECT pv FROM item_summary ORDER BY pv DESC LIMIT 20)) AS top20_item_pv,(SELECT SUM(buy) FROM (SELECT buy FROM item_summary ORDER BY buy DESC LIMIT 20)) AS top20_item_buy''',
            'catalog_ranking': '''WITH r AS(SELECT *,RANK() OVER(ORDER BY pv DESC) AS pv_rank,RANK() OVER(ORDER BY buy DESC) AS buy_rank FROM item_summary) SELECT item_id,pv,buy,users,buyers,pv_rank,buy_rank,buyers*1.0/users AS buyer_share FROM r WHERE pv_rank<=20 OR buy_rank<=20 ORDER BY pv_rank''',
            'validation_totals': '''SELECT (SELECT COUNT(*) FROM behavior) AS clean_rows,(SELECT COUNT(*) FROM bought_pairs) AS bought_pairs,(SELECT COALESCE(SUM(buy_events),0) FROM bought_pairs) AS bought_pair_events,(SELECT COUNT(*) FROM buy_paths) AS path_pairs,(SELECT COALESCE(SUM(buy_events),0) FROM buy_paths) AS path_buy_events,(SELECT SUM(pv) FROM item_summary) AS item_pv,(SELECT SUM(buy) FROM item_summary) AS item_buy,(SELECT SUM(pv) FROM category_summary) AS category_pv,(SELECT SUM(buy) FROM category_summary) AS category_buy,(SELECT SUM(pv) FROM category_item_summary) AS category_item_pv,(SELECT COUNT(*) FROM item_summary WHERE pv>0) AS viewed_items,(SELECT COUNT(*) FROM rf_scores) AS rf_users''',
            'active_day_distribution': '''SELECT active_day_count AS active_days,COUNT(*) AS users FROM user_summary GROUP BY active_day_count ORDER BY active_day_count''',
            'top20_rank_overlap': '''WITH r AS(SELECT item_id,RANK() OVER(ORDER BY pv DESC) AS pv_rank,RANK() OVER(ORDER BY buy DESC) AS buy_rank FROM item_summary) SELECT COUNT(*) FILTER(WHERE pv_rank<=20 AND buy_rank<=20) AS common_top20_items FROM r''',
        }

        results = {'quality': quality, 'methodology': {'dedup_key': ['user_id','item_id','timestamps'], 'dedup_keep': 'first source row', 'rf_frequency_tie_break': 'user_id, for deterministic recomputation; original NTILE ordering does not specify a tie-break', 'funnel': 'period-level user behavior intersections; not chronological or same-item funnel', 'path': 'period-level behavior combinations per user-item; not a proven chronological path', 'goods_buyer_share': 'distinct purchasing users / distinct users with any behavior for the given item/category', 'additional_analysis': ['day7_retention','user_intent_groups','repeat_buyers','item_matrix','catalog_ranking','minimum_sample_conversion_rankings','path_timestamp_checks']}}
        for name, sql in queries.items():
            log(f"Querying {name}")
            result=con.execute(sql)
            columns=[d[0] for d in result.description]
            normalized=[{k:normalize(v) for k,v in zip(columns,row)} for row in result.fetchall()]
            results[name]=normalized
            with (args.output/f"{name}.csv").open('w',newline='',encoding='utf-8') as handle:
                writer=csv.DictWriter(handle,fieldnames=columns)
                writer.writeheader()
                writer.writerows(normalized)
            save_json(args.output/'analysis_results.json',results)
        overview=results['overview'][0]
        totals=results['validation_totals'][0]
        assert overview['events']==quality['clean_rows']==totals['clean_rows']
        assert overview['events']==sum(overview[b] for b in ['pv','fav','cart','buy'])
        assert overview['pv']==totals['item_pv']==totals['category_pv']==totals['category_item_pv']==sum(x['pv'] for x in results['daily'])==sum(x['pv'] for x in results['hourly'])
        assert overview['buy']==totals['bought_pair_events']==totals['path_buy_events']==totals['item_buy']==totals['category_buy']==sum(x['buy'] for x in results['daily'])==sum(x['buy'] for x in results['hourly'])
        assert totals['bought_pairs']==totals['path_pairs']==sum(x['user_item_pairs'] for x in results['paths'])
        assert overview['buyers']==totals['rf_users']==sum(x['users'] for x in results['rf_classes'])
        reference_match=all(overview[k]==v for k,v in REFERENCE_COUNTS.items())
        if args.verify_reference and not reference_match:
            raise AssertionError('The four behavior totals do not match the full portfolio dataset')
        results['validation']={'all_reconciliations_passed':True,'reference_counts_checked':args.verify_reference,'tableau_behavior_counts_matched':reference_match}
        save_json(args.output/'analysis_results.json',results)
        log('All aggregate reconciliations passed')
        log('Aggregate results saved; keep the local working database out of version control')
    finally:
        con.close()


if __name__ == '__main__':
    main()
