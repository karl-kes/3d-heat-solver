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

# Measured by scripts/profile.ps1 (mean over 5 of 6 runs); mirror tab:ncu.
nx = np.array([8, 16, 32, 64, 128, 256, 512])
dram_pct = np.array([0.83, 3.62, 11.49, 52.4, 82.93, 90.57, 91.12])
dram_std = np.array([0.4, 0.03, 0.26, 0.56, 0.2, 0.04, 0.27])
compute_pct = np.array([0.2, 1.89, 13.29, 43.2, 50.4, 45.58, 45.54])
compute_std = np.array([0.02, 0.19, 0.1, 0.36, 0.13, 1.59, 0.21])
duration_ns = np.array([2240, 2560, 2764.8, 6809.6, 45196.8, 373670.4, 3035155.2])

PEAK_BW_GBPS = 448.0
PEAK_FLOPS_GFLOPS = 20300.0
RIDGE_OI = PEAK_FLOPS_GFLOPS / PEAK_BW_GBPS

FLOP_PER_CELL = 16
interior_cells = (nx - 2).astype(float) ** 3
achieved_gflops = FLOP_PER_CELL * interior_cells / duration_ns
fp32_pct = achieved_gflops / PEAK_FLOPS_GFLOPS * 100.0
achieved_bw_gbps = dram_pct / 100.0 * PEAK_BW_GBPS
oi_dram = achieved_gflops / achieved_bw_gbps

# Figure 1: utilization vs. grid size
fig, ax = plt.subplots(figsize=(3.3, 2.4))
ax.errorbar(
    nx, dram_pct, yerr=dram_std, fmt="o-", color="#4c72b0", markerfacecolor="white",
    markeredgewidth=1.1, capsize=2, elinewidth=0.8, label="DRAM throughput",
)
ax.errorbar(
    nx, compute_pct, yerr=compute_std, fmt="s-", color="#c44e52", markerfacecolor="white",
    markeredgewidth=1.1, capsize=2, elinewidth=0.8, label="SM utilization",
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
oi_range = np.logspace(-2, 3, 200)
memory_roof = np.minimum(oi_range * PEAK_BW_GBPS, PEAK_FLOPS_GFLOPS)

fig, ax = plt.subplots(figsize=(3.3, 2.6))
ax.loglog(oi_range, memory_roof, "-", color="0.3", linewidth=1.2, label="Roofline (RTX 3070)")
ax.axvline(RIDGE_OI, color="0.6", linestyle=":", linewidth=0.8)
ax.text(RIDGE_OI * 1.15, 30, "ridge point", fontsize=7, color="0.4", rotation=90, va="bottom")

large = nx >= 128
ax.scatter(
    oi_dram[~large], achieved_gflops[~large], marker="o", s=46,
    facecolor="white", edgecolor="#4c72b0", linewidth=1.2, zorder=5,
    label=r"Achieved, $n\leq64$ (L2-resident)",
)
ax.scatter(
    oi_dram[large], achieved_gflops[large], marker="o", s=52,
    color="#c44e52", zorder=6, label=r"Achieved, $n\geq128$ (DRAM-bound)",
)

# Label offsets (pts); clustered n>=64 points get fanned-out labels with leader lines.
label_offsets = {8: (9, -3), 16: (9, -3), 32: (11, -2), 64: (15, -3),
                 128: (-2, 19), 256: (-37, 8), 512: (-16, -21)}
for n_val, oi_val, gf in zip(nx, oi_dram, achieved_gflops):
    dx, dy = label_offsets[int(n_val)]
    arrow = (dict(arrowstyle="-", color="0.55", lw=0.4, shrinkA=1, shrinkB=3)
             if int(n_val) >= 64 else None)
    ax.annotate(
        f"${n_val}^3$", (oi_val, gf), textcoords="offset points",
        xytext=(dx, dy), fontsize=7, color="0.3", arrowprops=arrow,
    )

ax.set_xlabel("DRAM operational intensity (FLOP/byte)")
ax.set_ylabel("Achieved performance (GFLOP/s)")
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

# Derived quantities for paper.tex's tab:derived (kept in sync by hand).
print("\nn    dur(us)   GFLOP/s   FP32%   OI_DRAM")
for n_val, du, gf, fp, oi in zip(nx, duration_ns, achieved_gflops, fp32_pct, oi_dram):
    print(f"{n_val:<4} {du/1e3:>8.2f} {gf:>9.1f} {fp:>7.2f} {oi:>8.2f}")
