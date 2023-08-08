import os
from enum import Enum

import matplotlib.pyplot as plt
import pandas as pd

GREY = (80 / 255, 80 / 255, 80 / 255)
LIGHT_GREY = (217 / 255, 217 / 255, 217 / 255)

plt.rcParams["font.family"] = "sans-serif"
plt.rcParams["axes.unicode_minus"] = False
plt.rcParams["font.sans-serif"] = ["Segoe UI", "Helvetica"]
plt.rcParams["text.color"] = GREY
plt.rcParams["text.color"] = GREY
plt.rcParams["axes.labelcolor"] = GREY
plt.rcParams["xtick.color"] = GREY
plt.rcParams["ytick.color"] = GREY
plt.rcParams["svg.fonttype"] = "none"

BAR_WIDTH = 0.35
# load data
# TCP_STREAM figure
RESULTS = os.environ["RESULTS"]
OUT_DIR = os.environ["OUT_DIR"]

BLUE = (0 / 255, 120 / 255, 212 / 255)
LIGHT_BLUE = (80 / 255, 230 / 255, 255 / 255)
ORANGE = (255 / 255, 185 / 255, 0 / 255)
LIGHT_ORANGE = (254 / 255, 240 / 255, 0 / 255)

# Assume that ambient comes first
BAR_COLORS = (ORANGE, BLUE, BLUE)
BAR_COLORS_LIGHT = (LIGHT_ORANGE, LIGHT_BLUE, LIGHT_BLUE)


def create_fig():
    # rely on this ordering. This is bad.
    groups = ["\nAmbient", "\nSidecar", "\nNo Mesh"]
    x = list(range(len(groups)))

    fig, ax = plt.subplots(figsize=(8, 4))
    ax.spines["top"].set_visible(False)
    ax.spines["right"].set_visible(False)
    ax.spines["left"].set_visible(False)
    ax.spines["bottom"].set_visible(False)
    ax.tick_params(axis="both", which="both", length=0)
    ax.yaxis.grid(True, which="major", color=LIGHT_GREY)
    ax.set_axisbelow(True)
    ax.set_xlim(-0.5, 2.5)
    ax.set_xticks(x, groups)
    plt.yticks(fontsize=9)
    # ax.set_xlabel("Mesh")
    return fig, ax


def tcp_stream_graph():
    stream_df = pd.read_csv(
        f"./{RESULTS}/TCP_STREAM.csv", usecols=["THROUGHPUT", "NAMESPACES"]
    )
    gb = stream_df.groupby("NAMESPACES")
    groups = sorted(list(gb.groups.keys()))  # list for consistent ordering
    groups_pretty = [g[: g.find(":")] for g in groups]
    fig: plt.Figure
    ax: plt.Axes
    fig, ax = create_fig()

    height = [gb["THROUGHPUT"].mean()[g] for g in groups]
    yerr = [gb["THROUGHPUT"].std()[g] * 2 for g in groups]
    x = list(range(len(groups)))

    ax.bar(x=x, height=height, width=BAR_WIDTH, color=BLUE)

    ax.set_ylabel("Throughput (10^6 bits/second)")
    ax.set_ylim(0, max(height) * 1.12)

    fig.savefig(f"./{OUT_DIR}/TCP_STREAM.svg")


def tcp_rr_graph():
    stream_df = pd.read_csv(
        f"./{RESULTS}/TCP_RR.csv",
        usecols=[
            "MAX_LATENCY",
            "P90_LATENCY",
            "P99_LATENCY",
            "P50_LATENCY",
            "STDDEV_LATENCY",
            "NAMESPACES",
        ],
    )
    gb = stream_df.groupby("NAMESPACES")
    groups = list(gb.groups.keys())  # list for consistent ordering
    groups.sort()
    groups_pretty = [g[: g.find(":")] for g in groups]
    fig: plt.Figure
    ax: plt.Axes
    fig, ax = create_fig()

    height50 = [gb["P50_LATENCY"].median()[g] / 1000 for g in groups]
    height90 = [gb["P90_LATENCY"].median()[g] / 1000 for g in groups]
    height99 = [gb["P99_LATENCY"].median()[g] / 1000 for g in groups]
    x = list(range(len(groups)))

    ax.bar(x=x, height=height90, label="P90", color=LIGHT_BLUE, width=BAR_WIDTH)
    ax.bar(x=x, height=height50, label="P50", color=BLUE, width=BAR_WIDTH)

    ax.set_ylim(0, max(height90) * 1.12)
    ax.set_ylabel(r"Transaction speed (msec/transaction)")
    ax.legend()

    fig.savefig(f"./{OUT_DIR}/TCP_RR.svg")


def tcp_crr_graph():
    stream_df = pd.read_csv(
        f"./{RESULTS}/TCP_CRR.csv",
        usecols=[
            "P90_LATENCY",
            "P99_LATENCY",
            "P50_LATENCY",
            "STDDEV_LATENCY",
            "NAMESPACES",
        ],
    )
    gb = stream_df.groupby("NAMESPACES")
    groups = list(gb.groups.keys())  # list for consistent ordering
    groups.sort()
    fig: plt.Figure
    ax: plt.Axes
    fig, ax = create_fig()

    height50 = [gb["P50_LATENCY"].median()[g] / 1000 for g in groups]
    height90 = [gb["P90_LATENCY"].median()[g] / 1000 for g in groups]
    height99 = [gb["P99_LATENCY"].median()[g] / 1000 for g in groups]
    x = list(range(len(groups)))

    ax.bar(x=x, height=height90, label="P90", color=LIGHT_BLUE, width=BAR_WIDTH)
    ax.bar(x=x, height=height50, label="P50", color=BLUE, width=BAR_WIDTH)

    ax.set_ylim(0, max(height90) * 1.12)
    ax.set_ylabel("Transaction speed (msec/transaction)")
    ax.legend()

    fig.savefig(f"./{OUT_DIR}/TCP_CRR.svg")


0
if __name__ == "__main__":
    tcp_stream_graph()
    tcp_rr_graph()
    tcp_crr_graph()
