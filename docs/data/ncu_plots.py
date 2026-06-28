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

data = np.genfromtxt(DATA_DIR / "ncu.csv", delimiter=",", names=True)
nx = data["nx"].astype(int)
dram_pct = data["dram_pct"]
dram_std = data["dram_std"]
compute_pct = data["sm_pct"]
compute_std = data["sm_std"]
l2_hit_pct = data["l2_hit_pct"]
l2_hit_std = data["l2_hit_std"]
occupancy_pct = data["occupancy_pct"]
occupancy_std = data["occupancy_std"]
duration_ns = data["duration_ns"]

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


with open(TABLES_DIR / "ncu.tex", "w", encoding="utf-8") as out:
    out.write("\\resizebox{\\linewidth}{!}{\n")
    out.write("\\begin{tabular}{@{}lrrrrr@{}}\n")
    out.write("\\toprule\n")
    out.write("Grid size & DRAM \\% & GB/s & SM util.\\ \\% & L2 hit \\% & Occupancy \\% \\\\\n")
    out.write("\\midrule\n")
    for n, d, ds, bw, c, cs, l2, l2s, occ, occs in zip(
        nx, dram_pct, dram_std, achieved_bw_gbps,
        compute_pct, compute_std, l2_hit_pct, l2_hit_std, occupancy_pct, occupancy_std
    ):
        out.write(
            f"${int(n)}^3$ & ${latex_num(d)} \\pm {latex_num(ds)}$ & ${latex_num(bw)}$ & "
            f"${latex_num(c)} \\pm {latex_num(cs)}$ & ${latex_num(l2)} \\pm {latex_num(l2s)}$ & "
            f"${latex_num(occ)} \\pm {latex_num(occs)}$ \\\\\n"
        )
    out.write("\\bottomrule\n")
    out.write("\\end{tabular}\n")
    out.write("}\n")

with open(TABLES_DIR / "derived.tex", "w", encoding="utf-8") as out:
    out.write("\\begin{tabular}{@{}lrrrr@{}}\n")
    out.write("\\toprule\n")
    out.write("Grid size & Duration ($\\mu$s) & GFLOP/s & FP32 \\% & $\\mathrm{OI}_{\\text{DRAM}}$ \\\\\n")
    out.write("\\midrule\n")
    for n, du, gf, fp, oi in zip(nx, duration_ns, achieved_gflops, fp32_pct, oi_dram):
        out.write(f"${int(n)}^3$ & ${latex_num(du / 1e3)}$ & ${latex_num(gf)}$ & ${latex_num(fp)}$ & ${latex_num(oi)}$ \\\\\n")
    out.write("\\bottomrule\n")
    out.write("\\end{tabular}\n")

print(f"wrote {FIGURES_DIR / 'utilization.pdf'}, {FIGURES_DIR / 'roofline.pdf'}, {TABLES_DIR / 'ncu.tex'}, and {TABLES_DIR / 'derived.tex'}")

# Derived quantities for paper.tex's tab:derived.
print("\nn    dur(us)   GFLOP/s   FP32%   OI_DRAM")
for n_val, du, gf, fp, oi in zip(nx, duration_ns, achieved_gflops, fp32_pct, oi_dram):
    print(f"{n_val:<4} {du/1e3:>8.2f} {gf:>9.1f} {fp:>7.2f} {oi:>8.2f}")

