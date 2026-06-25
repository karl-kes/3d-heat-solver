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

FIGURES_DIR = Path(__file__).resolve().parent / "figures"
FIGURES_DIR.mkdir(exist_ok=True)

# From scripts/benchmark.ps1 (5-of-6-run mean +/- sample stddev per size).
# Update both here and in paper.tex's tab:perf if re-benchmarked.
sizes = np.array([8, 16, 32, 64, 128, 256, 512])
cpu_ms = np.array([3.40, 12.6, 71.8, 518, 3768, 28910, 226716])
cpu_std = np.array([0.701, 0.532, 1.43, 22.8, 49.7, 119, 900])
gpu_ms = np.array([25.5, 34.4, 26.5, 28.4, 62.6, 444, 3339])
gpu_std = np.array([5.94, 6.22, 6.44, 1.84, 0.624, 0.160, 0.991])
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

print(f"wrote {FIGURES_DIR / 'runtime.pdf'} and {FIGURES_DIR / 'speedup.pdf'}")
