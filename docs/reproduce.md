# 数据复现

项目主体使用 MySQL 8 完成分析，Tableau 展示结果。`scripts/recompute.py` 是使用 DuckDB 的独立复核入口：从同一原始文件重算聚合指标，检查不同汇总维度能否对账。它不会连接或修改 MySQL，也不会修改源文件。

## 数据与环境

- 官方来源：[淘宝用户购物行为数据集](https://tianchi.aliyun.com/dataset/649)。下载与使用遵循数据提供方的规则，原始数据不随本仓库分发。
- 本次复核使用的 ZIP 名为 `UserBehavior.csv.zip`，其中包含无表头的 `UserBehavior.csv`。
- 每行依次为 `user_id,item_id,category_id,behavior_type,timestamps`，行为类型为 `pv`、`fav`、`cart`、`buy`，时间戳单位为秒。
- 使用 Python 3.12 和 DuckDB 2.0.0 验证。运行依赖仅为 DuckDB，其余模块来自 Python 标准库。

在仓库根目录执行：

```bash
python -m venv .venv
source .venv/bin/activate
python -m pip install -r requirements.txt
python scripts/recompute.py --help
```

Windows 可使用 `.venv\Scripts\activate` 激活虚拟环境。

## 重算全量数据

将下载的数据保存在本地，例如 `data/raw/UserBehavior.csv.zip`，然后运行：

```bash
python scripts/recompute.py \
  --source data/raw/UserBehavior.csv.zip \
  --output results/recomputed \
  --memory-limit 2GB \
  --threads 4 \
  --verify-reference
```

也可直接读取解压后的 CSV：

```bash
python scripts/recompute.py \
  --source data/raw/UserBehavior.csv \
  --output results/from_csv \
  --verify-reference
```

`--verify-reference` 额外核对本项目全量数据的四类行为总数：浏览 89,660,668、收藏 2,888,258、加购 5,530,445、购买 2,015,807。该开关只用于相同的完整数据文件；使用小样本或合成数据验证流程时应省略。

默认输出目录与仓库中的 `data/aggregate/` 快照分开，便于对比。两种输入格式会各自记录源文件的 SHA-256；ZIP 与 CSV 虽然内容对应，文件哈希不同，不能复用彼此的中间数据库。

## 中间数据和继续运行

程序默认在输出目录创建 `recomputed.duckdb`，需要时可指定其他本地路径：

```bash
python scripts/recompute.py \
  --source data/raw/UserBehavior.csv.zip \
  --output results/recomputed \
  --database work/taobao.duckdb \
  --verify-reference
```

中间数据库已经存在时，程序默认拒绝覆盖。对同一源文件继续运行，需明确加 `--resume`，并使用与上次相同的输出与数据库参数：

```bash
python scripts/recompute.py \
  --source data/raw/UserBehavior.csv.zip \
  --output results/recomputed \
  --database work/taobao.duckdb \
  --resume \
  --verify-reference
```

程序核对源文件 SHA-256 与计算版本，避免误用其他数据的缓存。源文件变化或计算版本变化时，应指定新的数据库文件。已有但不是由本脚本创建的数据库会被拒绝使用。

ZIP 读取期间会产生约 3.67 GB 的临时 CSV，导入后自动删除；本次全量中间数据库约 2 GB，查询还可能使用磁盘暂存空间。运行前应预留充足空间，不能只按压缩包大小估计。内存上限默认 2 GB，线程数默认 4；实际耗时和磁盘峰值取决于硬件、数据和并发负载，不承诺固定完成时间。

本地数据库包含用户级工作表，仅用于计算，不应提交到 GitHub。最终导出的 CSV/JSON 都是聚合结果；完成后可自行删除中间数据库与其临时目录，之后仍可从原始文件重新计算。

## 与项目一致的统计口径

1. 时间按 UTC+08:00 处理，观察窗口为 2017-11-25 00:00:00（含）至 2017-12-04 00:00:00（不含）。
2. 在全文件范围按 `(user_id,item_id,timestamps)` 去重，保留源文件最先出现的记录。程序不假设同一用户的数据连续，也不只在单个分块中去重。
3. 留存以某日发生任意行为的活跃用户为分母；观察窗口末日的次日留存为 `null`，不是 0%。
4. 漏斗使用观察期内用户行为的交集，没有限定同一商品或严格的行为先后顺序。
5. 购买行为组合以用户—商品为粒度，代表窗口内出现过哪些行为，不能解释为已经验证的时序路径。
6. RF 只使用最近购买日期和购买行为次数，没有金额 M 维度。购买频次使用 `NTILE(5) OVER (ORDER BY buy,user_id)`，以用户 ID 固定同频次记录的排序。原 SQL 未指定这一排序，原看板的分层占比与这里的可复现版本不同。等人数分箱仍会将相同购买次数的用户分到不同评分，应结合业务阈值进一步评估。
7. 商品、品类的购买用户占比为购买去重用户除以该商品、品类发生任意行为的去重用户；不是严格的浏览后购买转化率。
8. 有少量商品 ID 关联多个品类。品类及品类内商品统计直接使用每条行为记录的品类。单商品明细中的 `category_id` 是便于展示的最小 ID；若 `category_count>1`，不能将其解释为唯一真实品类。

## 输出与核验

主要输出包括 `overview.csv`、`daily.csv`、`hourly.csv`、`retention.csv`、`funnel.csv`、`paths.csv`、`rf_classes.csv`、商品和品类排行，以及汇总的 `analysis_results.json`。

程序核对：清洗前后条数平衡；四类行为之和；日期、小时、商品、品类的 PV 和购买次数一致；购买组合的购买次数等于总购买次数；RF 人数等于购买人数。失败时以非零退出码结束，不将检查结果标记为通过。

已用小型合成数据实际执行 CSV 和 ZIP 两种入口，验证乱序用户的全局去重、窗口过滤、漏斗、组合、末日留存、缓存继续运行、源文件变化拒绝复用及完整样本参考校验开关。公开的全量聚合快照来自原始完整文件的重算，并与原 Tableau 保存的四类行为总次数核对一致。

## 重绘静态图表

图表从已公开的聚合结果读取，无需重跑原始数据：

```bash
python -m pip install -r requirements-viz.txt
python scripts/render_figures.py
```

图片输出到 `assets/`。中文字体优先选择本机已有的黑体、苹方、Noto CJK 或微软雅黑；若环境缺少中文字体，应先安装可用的中文字体后再重绘。
