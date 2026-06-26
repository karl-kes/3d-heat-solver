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

nx = np.array([16, 32, 64, 128, 256])

l2_self_similar = np.array(
    [0.2975357726, 0.0082576356, 0.0004219388, 0.0000369302, 0.0000029500]
)
l2_gaussian = np.array(
    [0.0083002293, 0.0017853108, 0.0004289477, 0.0001193513, 0.0000520277]
)
l2_cosine = np.array(
    [0.0029573802, 0.0007406752, 0.0001842881, 0.0000462171, 0.0000057420]
)

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

print(f"cosine fitted order (n=16..128): {-slope:.3f}")
print(f"wrote {FIGURES_DIR / 'convergence.pdf'}")
