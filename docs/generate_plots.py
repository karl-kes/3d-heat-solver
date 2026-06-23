# Regenerates the benchmark figures embedded in docs/paper.tex.
#
# Data is copied from the Performance table in README.md (scripts/benchmark.ps1
# output, 1000 steps, average of 5-of-6 runs). Update both places if the
# benchmark is re-run.
#
# Renders text with real LaTeX (mathptmx, matching IEEEtran's default Times
# font) so the figures look like part of the paper rather than a separate
# matplotlib default. Falls back to matplotlib's own mathtext if no LaTeX
# install is found.

import shutil
from pathlib import Path

import matplotlib

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

sizes = [8, 16, 32, 64, 128, 256, 512]
cpu_ms = [4.14, 13.8, 83.7, 535, 3805, 29856, 225321]
gpu_ms = [32.2, 22.7, 26.7, 31.8, 62.0, 446, 3336]
speedup = [c / g for c, g in zip(cpu_ms, gpu_ms)]

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
ax.loglog(
    sizes, cpu_ms, "o-", color=CPU_COLOR, markerfacecolor="white",
    markeredgewidth=1.1, label="CPU (OpenMP/SIMD)",
)
ax.loglog(
    sizes, gpu_ms, "s-", color=GPU_COLOR, markerfacecolor="white",
    markeredgewidth=1.1, label="GPU (CUDA)",
)
ax.set_xlabel(r"Grid size ($n$, for an $n^3$ grid)")
ax.set_ylabel("Runtime (ms)")
style_axes(ax)
ax.legend(frameon=False, loc="upper left")
fig.tight_layout(pad=0.4)
fig.savefig(FIGURES_DIR / "runtime.pdf", bbox_inches="tight")

fig, ax = plt.subplots(figsize=(3.3, 2.4))
ax.semilogx(
    sizes, speedup, "o-", color=SPEEDUP_COLOR, markerfacecolor="white",
    markeredgewidth=1.1,
)
ax.axhline(1.0, color="0.5", linestyle="--", linewidth=0.8)
ax.set_xlabel(r"Grid size ($n$, for an $n^3$ grid)")
ax.set_ylabel(r"Speedup ($T_{\mathrm{CPU}} / T_{\mathrm{GPU}}$)")
style_axes(ax)
fig.tight_layout(pad=0.4)
fig.savefig(FIGURES_DIR / "speedup.pdf", bbox_inches="tight")

print(f"wrote {FIGURES_DIR / 'runtime.pdf'} and {FIGURES_DIR / 'speedup.pdf'}")
