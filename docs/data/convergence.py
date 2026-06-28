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

data = np.genfromtxt(DATA_DIR / "convergence.csv", delimiter=",", names=True)
nx = data["nx"].astype(int)
l2_self_similar = data["self_similar"]
l2_gaussian = data["gaussian"]
l2_cosine = data["cosine"]

# Optional double-precision cosine sweep (built with -DHEAT_SOLVER_PRECISION=double),
# used to show the n=256 single-precision floor is an arithmetic artifact, not the scheme.
fp64_path = DATA_DIR / "convergence_fp64.csv"
l2_cosine_fp64 = None
if fp64_path.exists():
    data_fp64 = np.genfromtxt(fp64_path, delimiter=",", names=True)
    if np.array_equal(data_fp64["nx"].astype(int), nx):
        l2_cosine_fp64 = data_fp64["cosine"]

# Fit the exact-reference (cosine) order over n<=128; nx=256 reaches the single-precision floor.
fit_mask = nx <= 128
slope, intercept = np.polyfit(np.log2(nx[fit_mask]), np.log2(l2_cosine[fit_mask]), 1)
fit_x = np.array([nx[fit_mask].min(), nx[fit_mask].max()])
fit_y = 2 ** (slope * np.log2(fit_x) + intercept)

fig, ax = plt.subplots(figsize=(3.3, 2.6))
ax.loglog(
    nx, l2_self_similar, "^--", color="0.6", markerfacecolor="white",
    markeredgewidth=1.0, label="Gaussian, self-similar (invalid)",
)
ax.loglog(
    nx, l2_gaussian, "o-", color="#4c72b0", markerfacecolor="white",
    markeredgewidth=1.1, label="Gaussian, fixed domain",
)
ax.loglog(
    nx, l2_cosine, "s-", color="#55a868", markerfacecolor="white",
    markeredgewidth=1.1, label="cosine eigenmode (exact)",
)
if l2_cosine_fp64 is not None:
    ax.loglog(
        nx, l2_cosine_fp64, "D:", color="#8172b3", markerfacecolor="white",
        markeredgewidth=1.1, label="cosine eigenmode (fp64)",
    )
ax.loglog(
    fit_x, fit_y, "-", color="#c44e52", linewidth=1.0,
    label=rf"fit (cosine), $n=16..128$: order $\approx {-slope:.2f}$",
)
ax.set_xlabel(r"Grid size ($n$, for an $n^3$ grid)")
ax.set_ylabel(r"Global $L_2$ relative error")
ax.set_xticks(nx)
ax.set_xticklabels([str(n) for n in nx])
ax.grid(True, which="major", linestyle="-", linewidth=0.4, color="0.85")
ax.grid(True, which="minor", linestyle=":", linewidth=0.3, color="0.92")
for spine in ("top", "right"):
    ax.spines[spine].set_visible(False)
ax.tick_params(direction="out", length=3)
ax.legend(frameon=False, loc="lower left", fontsize=7)
fig.tight_layout(pad=0.4)
fig.savefig(FIGURES_DIR / "convergence.pdf", bbox_inches="tight")


def latex_sci(value):
    mantissa, exponent = f"{value:.2e}".split("e")
    return rf"{float(mantissa):.2f} \times 10^{{{int(exponent)}}}"

with open(TABLES_DIR / "convergence.tex", "w", encoding="utf-8") as out:
    if l2_cosine_fp64 is not None:
        out.write("\\begin{tabular}{@{}cccc@{}}\n")
        out.write("\\toprule\n")
        out.write("$n$ & Gaussian & cosine (fp32) & cosine (fp64) \\\\\n")
        out.write("\\midrule\n")
        for n, g, c, c64 in zip(nx, l2_gaussian, l2_cosine, l2_cosine_fp64):
            out.write(
                f"{int(n)} & ${latex_sci(g)}$ & ${latex_sci(c)}$ & ${latex_sci(c64)}$ \\\\\n"
            )
        out.write("\\bottomrule\n")
        out.write("\\end{tabular}\n")
    else:
        out.write("\\begin{tabular}{@{}ccc@{}}\n")
        out.write("\\toprule\n")
        out.write("$n$ & Gaussian & cosine \\\\\n")
        out.write("\\midrule\n")
        for n, g, c in zip(nx, l2_gaussian, l2_cosine):
            out.write(f"{int(n)} & ${latex_sci(g)}$ & ${latex_sci(c)}$ \\\\\n")
        out.write("\\bottomrule\n")
        out.write("\\end{tabular}\n")

print(f"cosine fitted order (n=16..128): {-slope:.3f}")
if l2_cosine_fp64 is not None:
    slope64 = np.polyfit(np.log2(nx[fit_mask]), np.log2(l2_cosine_fp64[fit_mask]), 1)[0]
    print(f"cosine fp64 fitted order (n=16..128): {-slope64:.3f}")
print(f"wrote {FIGURES_DIR / 'convergence.pdf'} and {TABLES_DIR / 'convergence.tex'}")
