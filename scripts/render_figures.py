#!/usr/bin/env python3
"""Render portfolio figures from the published aggregate results.

Run from the repository: python scripts/render_figures.py
Requires matplotlib and numpy. No raw user records are read.
"""
from __future__ import annotations

import json
import os
from pathlib import Path
import tempfile

os.environ.setdefault("MPLCONFIGDIR", str(Path(tempfile.gettempdir()) / "taobao-portfolio-mpl"))
os.environ.setdefault("XDG_CACHE_HOME", str(Path(tempfile.gettempdir()) / "taobao-portfolio-cache"))

import matplotlib
matplotlib.use("Agg")
from matplotlib import pyplot as plt
from matplotlib import font_manager as fm
from matplotlib.patches import FancyBboxPatch
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets"
DATA = ROOT / "data" / "aggregate" / "analysis_results.json"
BG = "#F4F7FA"
INK = "#152B43"
MUTED = "#62758A"
TEAL = "#167D8D"
TEAL_LIGHT = "#A2CDD3"
ORANGE = "#D77542"
GRID = "#E4EAF0"


def configure_font():
    candidates = [
        Path("/System/Library/Fonts/STHeiti Light.ttc"),
        Path("/System/Library/Fonts/PingFang.ttc"),
        Path("/System/Library/Fonts/Supplemental/Songti.ttc"),
        Path("/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc"),
        Path("C:/Windows/Fonts/msyh.ttc"),
    ]
    for candidate in candidates:
        if candidate.exists():
            fm.fontManager.addfont(str(candidate))
            plt.rcParams["font.family"] = fm.FontProperties(fname=str(candidate)).get_name()
            break
    else:
        plt.rcParams["font.sans-serif"] = ["Noto Sans CJK SC", "Microsoft YaHei", "SimHei", "DejaVu Sans"]
    plt.rcParams.update({"axes.unicode_minus": False, "font.size": 11,
                         "axes.labelcolor": MUTED, "text.color": INK,
                         "xtick.color": MUTED, "ytick.color": MUTED,
                         "axes.edgecolor": GRID, "figure.facecolor": BG,
                         "axes.facecolor": "white", "savefig.facecolor": BG})


def style(ax, axis="y"):
    ax.spines[["top", "right", "left"]].set_visible(False)
    ax.spines["bottom"].set_color(GRID)
    ax.tick_params(length=0, pad=7)
    ax.grid(axis=axis, color=GRID, linewidth=.7)
    ax.set_axisbelow(True)


def save(fig, name):
    OUT.mkdir(parents=True, exist_ok=True)
    fig.savefig(OUT / name, dpi=160, bbox_inches=None)
    plt.close(fig)


def header(fig, title, subtitle, small=False):
    fig.text(.055, .945, title, fontsize=23 if not small else 21, weight="bold", va="top")
    fig.text(.055, .887, subtitle, fontsize=11 if not small else 10.5, color=MUTED, va="top")


def footer(fig, text):
    fig.text(.055, .028, text, fontsize=9, color=MUTED, va="bottom")


def draw_daily(ax, daily, compact=False):
    x = np.arange(len(daily))
    pv = np.array([d["pv"] for d in daily]) / 1e6
    uv = np.array([d["uv"] for d in daily]) / 1e4
    ax.bar(x, pv, color=[TEAL if i < 7 else ORANGE for i in x], width=.58, zorder=2)
    ax.set_xticks(x, [d["date"][5:].replace("-", "/") for d in daily], fontsize=9 if compact else 11)
    ax.set_ylim(0, 15 if compact else 15.5)
    ax.set_ylabel("PV（百万次）", fontsize=9 if compact else 11)
    style(ax)
    ax2 = ax.twinx()
    ax2.plot(x, uv, color=INK, marker="o", markersize=3.5 if compact else 5, lw=1.8, label="UV")
    ax2.set_ylim(0, 115)
    ax2.set_ylabel("UV（万人）", fontsize=9 if compact else 11, color=INK)
    ax2.spines[["top", "left", "right", "bottom"]].set_visible(False)
    ax2.tick_params(length=0, labelsize=9 if compact else 11, colors=MUTED)
    ax.text(.02, .96, "柱：PV     线：UV", transform=ax.transAxes, fontsize=9 if compact else 11, color=MUTED, va="top")
    if compact:
        ax.annotate("12/2 PV +26.86%", xy=(7, pv[7]), xytext=(3.9, 13.8), fontsize=9, color=ORANGE,
                    arrowprops=dict(arrowstyle="-", color=ORANGE))
    else:
        for i, value in enumerate(pv):
            ax.text(i, value+.45, f"{value:.2f}", ha="center", fontsize=10, color=TEAL if i<7 else ORANGE)
    return ax2


def draw_hourly(ax, hourly, compact=False):
    x = np.array([d["hour"] for d in hourly])
    pv = np.array([d["pv"] for d in hourly]) / 1e6
    ratio = np.array([d["buy"] / d["pv"] for d in hourly]) * 100
    ax.bar(x, pv, color=TEAL_LIGHT, width=.76, zorder=2)
    ax.bar([21], [pv[21]], color=TEAL, width=.76, zorder=3)
    ax.set_xlim(-.8, 23.8)
    ax.set_ylim(0, 9.6)
    ax.set_xticks(np.arange(0, 24, 3))
    ax.set_xlabel("小时（9天按整点合并）", fontsize=9 if compact else 11)
    ax.set_ylabel("PV（百万次）", fontsize=9 if compact else 11)
    style(ax)
    ax2 = ax.twinx()
    ax2.plot(x, ratio, color=ORANGE, lw=1.9, zorder=4)
    ax2.scatter([10,21], [ratio[10],ratio[21]], s=20 if compact else 36, color=ORANGE, zorder=5)
    ax2.set_ylim(0, 3.8)
    ax2.set_ylabel("购买次数 / PV（%）", fontsize=9 if compact else 11, color=ORANGE)
    ax2.spines[["top", "left", "right", "bottom"]].set_visible(False)
    ax2.tick_params(length=0, labelsize=9 if compact else 11)
    ax2.annotate("10点 2.95%", xy=(10, ratio[10]), xytext=(7.5, 3.4), fontsize=9 if compact else 11,
                 color=ORANGE, arrowprops=dict(arrowstyle="-",color=ORANGE))
    ax.annotate("21点 PV峰值", xy=(21,pv[21]), xytext=(16,9.05), fontsize=9 if compact else 11,
                color=TEAL,arrowprops=dict(arrowstyle="-",color=TEAL))
    return ax2


def draw_funnel(ax, f, compact=False):
    vals=[f["browsing_users"],f["intent_users"],f["funnel_buyers"]]
    labels=["浏览", "浏览且收藏/加购", "浏览且收藏/加购且购买"]
    y=np.array([2,1,0])
    for i,(value,label) in enumerate(zip(vals,labels)):
        ax.barh(y[i], value/1e4, color=[TEAL_LIGHT,TEAL,INK][i], height=.58)
        ax.text(1.5,y[i],label,va="center",color=INK if i==0 else "white",fontsize=9 if compact else 12)
        ax.text(value/1e4+1.2,y[i],f"{value/1e4:.2f}万",va="center",fontsize=9 if compact else 12,color=INK)
    ax.set_xlim(0,119)
    ax.set_ylim(-.65,2.8)
    ax.set_yticks([])
    ax.set_xticks([0,25,50,75,100])
    ax.set_xlabel("去重用户数（万人）", fontsize=9 if compact else 11)
    style(ax,"x")
    if compact:
        ax.text(.98,.98,"总体 61.00%",transform=ax.transAxes,ha="right",va="top",fontsize=12,weight="bold",color=TEAL)


def draw_rank(ax, ranking, compact=False):
    rows = sorted([d for d in ranking if d["pv_rank"] <= 5],key=lambda d:d["pv_rank"])
    if compact: rows=rows[:3]
    y=np.arange(len(rows))[::-1]
    for yi,row in zip(y,rows):
        ax.plot([row["pv_rank"],row["buy_rank"]],[yi,yi],color=GRID,lw=4,zorder=1)
        ax.scatter([row["pv_rank"]],[yi],color=TEAL,s=36 if compact else 62,zorder=3)
        ax.scatter([row["buy_rank"]],[yi],color=ORANGE,s=36 if compact else 62,zorder=3)
        ax.text(row["pv_rank"],yi+.15,str(row["pv_rank"]),ha="center",fontsize=9 if compact else 11,color=TEAL)
        ax.text(row["buy_rank"],yi+.15,str(row["buy_rank"]),ha="center",fontsize=9 if compact else 11,color=ORANGE)
    ax.set_xscale("log")
    ax.set_xlim(.65,4500)
    ax.set_ylim(-.85,len(rows)-.35)
    ax.set_yticks(y,[str(d["item_id"]) for d in rows],fontsize=9 if compact else 11)
    ax.set_xticks([1,10,100,1000],["1","10","100","1000"])
    ax.minorticks_off()
    ax.set_ylabel("商品ID",fontsize=9 if compact else 11)
    ax.set_xlabel("排名（越小越靠前，对数刻度）",fontsize=9 if compact else 11)
    style(ax,"x")
    ax.scatter([],[],color=TEAL,label="浏览次数排名")
    ax.scatter([],[],color=ORANGE,label="购买次数排名")
    ax.legend(frameon=False,loc="lower center",bbox_to_anchor=(.5,.01),fontsize=8 if compact else 10,ncol=2)


def main():
    configure_font()
    r=json.loads(DATA.read_text(encoding="utf-8"))
    daily,hourly=r["daily"],r["hourly"]
    f=r["funnel"][0]
    ranking=r["catalog_ranking"]

    fig=plt.figure(figsize=(14,8),facecolor=BG)
    header(fig,"流量增长主要来自访客规模扩大","2017/11/25—12/03 · 清洗后100,095,178条行为记录 · 所给样本内统计")
    ax=fig.add_axes([.08,.20,.82,.59])
    draw_daily(ax,daily)
    fig.text(.08,.102,"12月2日较前日：PV +26.86%     UV +30.80%     人均PV -3.01%",fontsize=14,color=TEAL,weight="bold")
    footer(fig,"PV为浏览行为次数；UV为当日发生浏览行为的去重用户。结果不代表淘宝全站规模。")
    save(fig,"daily_activity.png")

    fig=plt.figure(figsize=(14,8),facecolor=BG)
    header(fig,"行为量高峰与购买次数比高峰不同","2017/11/25—12/03 · 9天按小时合并 · 89,660,668次浏览 / 2,015,807次购买行为")
    ax=fig.add_axes([.08,.21,.82,.59])
    draw_hourly(ax,hourly)
    fig.text(.08,.105,"21点：PV 7,538,381 / 购买145,431次    ·    10点购买次数/PV 2.95%，21点为1.93%",fontsize=12.5,color=TEAL,weight="bold")
    footer(fig,"购买次数/PV为同一小时分桶下的事件次数比，不代表购买由当小时浏览产生，也不是严格时序转化率。")
    save(fig,"hourly_activity.png")

    fig=plt.figure(figsize=(14,8),facecolor=BG)
    header(fig,"用户行为交集漏斗","2017/11/25—12/03 · 以浏览用户为起点，后一层同时满足前面各层条件")
    ax=fig.add_axes([.08,.24,.82,.53])
    draw_funnel(ax,f)
    fig.text(.08,.13,"第2层 / 第1层  86.93%",fontsize=14,color=TEAL,weight="bold")
    fig.text(.40,.13,"第3层 / 第2层  70.17%",fontsize=14,color=TEAL,weight="bold")
    fig.text(.73,.13,"总体  61.00%",fontsize=14,color=INK,weight="bold")
    footer(fig,"统计9天内用户是否发生各类行为；没有限定同一商品或行为先后。购买层600,278人并非全部购买用户。")
    save(fig,"conversion_funnel.png")

    fig=plt.figure(figsize=(14,8),facecolor=BG)
    header(fig,"浏览热度与购买排名存在明显差异","2017/11/25—12/03 · 浏览次数排名前5的商品 · 以购买行为次数比较表现")
    ax=fig.add_axes([.14,.23,.76,.55])
    draw_rank(ax,ranking)
    fig.text(.08,.115,"浏览量第1商品：购买次数第461    ·    浏览前20与购买前20商品仅3个重合",fontsize=13,color=TEAL,weight="bold")
    footer(fig,"商品ID为匿名标识；购买次数不是销售件数、订单数或销售额。此图比较排名，不证明浏览与购买的因果关系。")
    save(fig,"item_rank_comparison.png")

    fig=plt.figure(figsize=(16,11),facecolor=BG)
    header(fig,"淘宝用户行为与商品转化分析","2017/11/25—12/03 · MySQL分析与Tableau展示 · 以下图表由公开聚合结果重新绘制",small=True)
    cards=[("清洗后行为记录","100,095,178","约1亿条"),("去重用户","987,991","98.8万人"),("购买用户","672,404","67.24万人"),("行为交集漏斗","61.00%","浏览起点的总体比例")]
    for i,(label,value,note) in enumerate(cards):
        x=.055+i*.235
        rect=FancyBboxPatch((x,.737),.218,.111,boxstyle="round,pad=.008,rounding_size=.009",transform=fig.transFigure,facecolor="white",edgecolor="none",zorder=0)
        fig.add_artist(rect)
        fig.text(x+.013,.825,label,fontsize=10.5,color=MUTED,va="top")
        fig.text(x+.013,.796,value,fontsize=23,weight="bold",color=TEAL,va="top")
        fig.text(x+.013,.755,note,fontsize=9,color=MUTED,va="top")
    axes=[fig.add_axes([.075,.433,.37,.22]),fig.add_axes([.565,.433,.35,.22]),fig.add_axes([.075,.109,.37,.22]),fig.add_axes([.565,.109,.35,.22])]
    titles=["流量变化：12月2日明显增长","日内行为：21点浏览最多","用户交集：98.41万至60.03万","商品差异：浏览热度与购买排名"]
    for ax,title in zip(axes,titles):
        ax.set_title(title,loc="left",fontsize=12,weight="bold",pad=20)
    draw_daily(axes[0],daily,True)
    draw_hourly(axes[1],hourly,True)
    draw_funnel(axes[2],f,True)
    draw_rank(axes[3],ranking,True)
    footer(fig,"所给样本内统计；漏斗为期内行为交集，未限定同商品或时间顺序；购买次数/PV为次数比。完整定义见README与SQL方法说明。")
    save(fig,"overview.png")
    for path in sorted(OUT.glob("*.png")):
        print(path.relative_to(ROOT),path.stat().st_size)


if __name__=="__main__":
    main()
