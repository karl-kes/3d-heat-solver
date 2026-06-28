import shutil
from pathlib import Path

import matplotlib
import numpy as np

if shutil.which("latex"):
    matplotlib.rcParams["text.usetex"] = True
    matplotlib.rcParams["text.latex.preamble"] = r"\usepackage{mathptmx}"
else:
    matplotlib.rcParams["mathtext.fontset"] = "stix"
    matplotlib.rcParams["font.family"] = "serif"

import matplotlib.pyplot as plt

matplotlib.rcParams.update(
    {
        "font.size": 9,
        "axes.linewidth": 0.8,
        "xtick.major.width": 0.8,
        "ytick.major.width": 0.8,
        "lines.markersize": 5,
        "lines.linewidth": 1.3,
        "savefig.dpi": 300,
        "pdf.fonttype": 42,
    }
)

DOCS_DIR = Path(__file__).resolve().parents[1]
FIGURES_DIR = DOCS_DIR / "figures"
FIGURES_DIR.mkdir(exist_ok=True)
DATA_DIR = Path(__file__).resolve().parent
TABLES_DIR = DOCS_DIR / "tables"
TABLES_DIR.mkdir(exist_ok=True)

benchmark = np.genfromtxt(DATA_DIR / "benchmark.csv", delimiter=",", names=True)
sizes = benchmark["size"].astype(int)
cpu_ms = benchmark["cpu_ms"]
cpu_std = benchmark["cpu_std"]
gpu_ms = benchmark["gpu_ms"]
gpu_std = benchmark["gpu_std"]
speedup = cpu_ms / gpu_ms
# standard error propagation for a ratio of two independent quantities
speedup_std = speedup * np.sqrt((cpu_std / cpu_ms) ** 2 + (gpu_std / gpu_ms) ** 2)

CPU_COLOR = "#c44e52"
GPU_COLOR = "#4c72b0"
SPEEDUP_COLOR = "#55a868"


def style_axes(ax):
    ax.grid(True, which="major", linestyle="-", linewidth=0.4, color="0.85")
    ax.grid(True, which="minor", linestyle=":", linewidth=0.3, color="0.92")
    ax.set_xticks(sizes)
    ax.set_xticklabels([str(s) for s in sizes])
    for spine in ("top", "right"):
        ax.spines[spine].set_visible(False)
    ax.tick_params(direction="out", length=3)


fig, ax = plt.subplots(figsize=(3.3, 2.4))
ax.errorbar(
    sizes, cpu_ms, yerr=cpu_std, fmt="o-", color=CPU_COLOR, markerfacecolor="white",
    markeredgewidth=1.1, capsize=2, elinewidth=0.8, label="CPU (OpenMP/SIMD)",
)
ax.errorbar(
    sizes, gpu_ms, yerr=gpu_std, fmt="s-", color=GPU_COLOR, markerfacecolor="white",
    markeredgewidth=1.1, capsize=2, elinewidth=0.8, label="GPU (CUDA)",
)
ax.set_xscale("log")
ax.set_yscale("log")
ax.set_xlabel(r"Grid size ($n$, for an $n^3$ grid)")
ax.set_ylabel("Runtime (ms)")
style_axes(ax)
ax.legend(frameon=False, loc="upper left")
fig.tight_layout(pad=0.4)
fig.savefig(FIGURES_DIR / "runtime.pdf", bbox_inches="tight")

fig, ax = plt.subplots(figsize=(3.3, 2.4))
ax.errorbar(
    sizes, speedup, yerr=speedup_std, fmt="o-", color=SPEEDUP_COLOR,
    markerfacecolor="white", markeredgewidth=1.1, capsize=2, elinewidth=0.8,
)
ax.set_xscale("log")
ax.axhline(1.0, color="0.5", linestyle="--", linewidth=0.8)
ax.set_xlabel(r"Grid size ($n$, for an $n^3$ grid)")
ax.set_ylabel(r"Speedup ($T_{\mathrm{CPU}} / T_{\mathrm{GPU}}$)")
style_axes(ax)
fig.tight_layout(pad=0.4)
fig.savefig(FIGURES_DIR / "speedup.pdf", bbox_inches="tight")

def latex_num(value):
    if value == 0:
        return "0"
    abs_value = abs(value)
    if abs_value >= 1000:
        return f"{value:,.0f}".replace(",", "{,}")
    if abs_value >= 100:
        return f"{value:.0f}"
    if abs_value >= 10:
        return f"{value:.1f}"
    if abs_value >= 1:
        return f"{value:.2f}".rstrip("0").rstrip(".")
    return f"{value:.3g}"


with open(TABLES_DIR / "perf.tex", "w", encoding="utf-8") as out:
    out.write("\\begin{tabular}{@{}lrrr@{}}\n")
    out.write("\\toprule\n")
    out.write("Grid size & CPU (ms) & GPU (ms) & Speedup \\\\\n")
    out.write("\\midrule\n")
    for n, c, cs, g, gs, s, ss in zip(sizes, cpu_ms, cpu_std, gpu_ms, gpu_std, speedup, speedup_std):
        out.write(
            f"${int(n)}^3$ & ${latex_num(c)} \\pm {latex_num(cs)}$ & "
            f"${latex_num(g)} \\pm {latex_num(gs)}$ & ${latex_num(s)} \\pm {latex_num(ss)}\\times$ \\\\\n"
        )
    out.write("\\bottomrule\n")
    out.write("\\end{tabular}\n")

print(f"wrote {FIGURES_DIR / 'runtime.pdf'}, {FIGURES_DIR / 'speedup.pdf'}, and {TABLES_DIR / 'perf.tex'}")

