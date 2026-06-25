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

# From scripts/profile.ps1 (5-of-6-run Nsight Compute mean +/- sample stddev
# per size; run from an elevated PowerShell). Update both here and in
# paper.tex's tab:ncu if re-profiled.
nx = np.array([8, 16, 32, 64, 128, 256, 512])
dram_pct = np.array([0.83, 3.62, 11.49, 52.4, 82.93, 90.57, 91.12])
dram_std = np.array([0.4, 0.03, 0.26, 0.56, 0.2, 0.04, 0.27])
compute_pct = np.array([0.2, 1.89, 13.29, 43.2, 50.4, 45.58, 45.54])
compute_std = np.array([0.02, 0.19, 0.1, 0.36, 0.13, 1.59, 0.21])

PEAK_BW_GBPS = 448.0
PEAK_FLOPS_GFLOPS = 20300.0
KERNEL_OI = 0.5
RIDGE_OI = PEAK_FLOPS_GFLOPS / PEAK_BW_GBPS

# Figure 1: utilization vs. grid size
fig, ax = plt.subplots(figsize=(3.3, 2.4))
ax.errorbar(
    nx, dram_pct, yerr=dram_std, fmt="o-", color="#4c72b0", markerfacecolor="white",
    markeredgewidth=1.1, capsize=2, elinewidth=0.8, label="DRAM throughput",
)
ax.errorbar(
    nx, compute_pct, yerr=compute_std, fmt="s-", color="#c44e52", markerfacecolor="white",
    markeredgewidth=1.1, capsize=2, elinewidth=0.8, label="Compute throughput",
)
ax.set_xscale("log")
ax.set_xlabel(r"Grid size ($n$, for an $n^3$ grid)")
ax.set_ylabel(r"\% of peak")
ax.set_xticks(nx)
ax.set_xticklabels([str(n) for n in nx])
ax.set_ylim(0, 100)
ax.grid(True, which="major", linestyle="-", linewidth=0.4, color="0.85")
for spine in ("top", "right"):
    ax.spines[spine].set_visible(False)
ax.tick_params(direction="out", length=3)
ax.legend(frameon=False, loc="center left", fontsize=7.5)
fig.tight_layout(pad=0.4)
fig.savefig(FIGURES_DIR / "utilization.pdf", bbox_inches="tight")

# Figure 2: roofline
achieved_bw_gbps = dram_pct / 100.0 * PEAK_BW_GBPS
achieved_bw_std = dram_std / 100.0 * PEAK_BW_GBPS
achieved_y_gflops = KERNEL_OI * achieved_bw_gbps
achieved_y_std = KERNEL_OI * achieved_bw_std

oi_range = np.logspace(-2, 3, 200)
memory_roof = np.minimum(oi_range * PEAK_BW_GBPS, PEAK_FLOPS_GFLOPS)

fig, ax = plt.subplots(figsize=(3.3, 2.6))
ax.loglog(oi_range, memory_roof, "-", color="0.3", linewidth=1.2, label="Roofline (RTX 3070)")
ax.axvline(RIDGE_OI, color="0.6", linestyle=":", linewidth=0.8)
ax.text(RIDGE_OI * 1.15, 30, "ridge point", fontsize=7, color="0.4", rotation=90, va="bottom")

ax.axvline(KERNEL_OI, color="#4c72b0", linestyle="--", linewidth=0.9)
ax.errorbar(
    [KERNEL_OI] * len(nx), achieved_y_gflops, yerr=achieved_y_std, fmt="o",
    markersize=4.7, capsize=2, elinewidth=0.8,
    markerfacecolor="white", markeredgecolor="#c44e52", ecolor="#c44e52",
    markeredgewidth=1.1, zorder=5, label="Achieved (this kernel, $n=8..512$)",
)
ax.scatter(
    [KERNEL_OI], [KERNEL_OI * PEAK_BW_GBPS], marker="x", s=30,
    color="0.3", zorder=5, label="Ceiling at OI=0.5 (100\\% BW)",
)

ax.set_xlabel("Naive operational intensity (FLOP/byte)")
ax.set_ylabel("Performance (GFLOP/s)")
ax.set_xlim(1e-1, 1e3)
ax.set_ylim(1, 5e4)
ax.grid(True, which="major", linestyle="-", linewidth=0.4, color="0.85")
ax.grid(True, which="minor", linestyle=":", linewidth=0.3, color="0.92")
for spine in ("top", "right"):
    ax.spines[spine].set_visible(False)
ax.tick_params(direction="out", length=3)
ax.legend(frameon=False, loc="upper left", fontsize=6.5)
fig.tight_layout(pad=0.4)
fig.savefig(FIGURES_DIR / "roofline.pdf", bbox_inches="tight")

print(f"wrote {FIGURES_DIR / 'utilization.pdf'} and {FIGURES_DIR / 'roofline.pdf'}")
