import argparse
import csv
import math
import os
import subprocess
import sys
from pathlib import Path


DOCS_DIR = Path(__file__).resolve().parents[1]
PROJECT_ROOT = DOCS_DIR.parent
DATA_DIR = Path(__file__).resolve().parent
DEFAULT_SIZES = [16, 32, 64, 128, 256]
EXE_NAME = "convergence_probe.exe" if os.name == "nt" else "convergence_probe"
DEFAULT_CPU_EXE = PROJECT_ROOT / "build-nocuda" / EXE_NAME
FIXED_DOMAIN_STEPS = {16: 3, 32: 11, 64: 41, 128: 161, 256: 641}
COSINE_STEPS = {16: 21, 32: 112, 64: 510, 128: 2174, 256: 8720}

# The eigenmode order is fit over the grids below the single-precision floor that
# the fp32 sweep hits at n=256 (see the paper's convergence discussion).
ORDER_FIT_MAX_N = 128


def run_probe(exe, n, steps, dx, ic):
    cmd = [
        str(exe),
        "--nx", str(n),
        "--ny", str(n),
        "--nz", str(n),
        "--steps", str(steps),
        "--dx", f"{dx:.17g}",
        "--dy", f"{dx:.17g}",
        "--dz", f"{dx:.17g}",
        "--ic", ic,
        "--output-interval", "0",
    ]
    output = subprocess.check_output(cmd, text=True).strip()
    return float(output.split(",")[-2])


def sweep(exe, sizes):
    rows = []
    for n in sizes:
        self_similar = run_probe(exe, n, steps=40, dx=1.0, ic="gaussian")

        dx = 1.0 / n
        gaussian = run_probe(exe, n, steps=FIXED_DOMAIN_STEPS[n], dx=dx, ic="gaussian")
        cosine = run_probe(exe, n, steps=COSINE_STEPS[n], dx=dx, ic="cosine")

        rows.append({
            "nx": n,
            "self_similar": self_similar,
            "gaussian": gaussian,
            "cosine": cosine,
        })
        print(
            f"n={n}: self_similar={self_similar:.10e}, "
            f"gaussian={gaussian:.10e}, cosine={cosine:.10e}"
        )
    return rows


def write_csv(path, rows):
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=["nx", "self_similar", "gaussian", "cosine"])
        writer.writeheader()
        writer.writerows(rows)


def fitted_order(rows, column, max_n=ORDER_FIT_MAX_N):
    """Least-squares slope of log2(error) vs log2(n), over grids up to max_n."""
    pts = [(r["nx"], r[column]) for r in rows if r["nx"] <= max_n]
    xs = [math.log2(n) for n, _ in pts]
    ys = [math.log2(err) for _, err in pts]
    mean_x = sum(xs) / len(xs)
    mean_y = sum(ys) / len(ys)
    cov = sum((x - mean_x) * (y - mean_y) for x, y in zip(xs, ys))
    var = sum((x - mean_x) ** 2 for x in xs)
    return -cov / var


def main():
    parser = argparse.ArgumentParser(description="Generate docs/data/convergence.csv from convergence_probe.")
    parser.add_argument(
        "--exe",
        type=Path,
        default=DEFAULT_CPU_EXE,
        help="Path to the CPU convergence_probe executable.",
    )
    parser.add_argument(
        "--gpu-exe",
        type=Path,
        default=None,
        help="Optional CUDA convergence_probe executable. When given, the full sweep is also "
             "run on the GPU backend, written to --gpu-output, and checked to reproduce the "
             "CPU sweep's second-order convergence.",
    )
    parser.add_argument("--output", type=Path, default=DATA_DIR / "convergence.csv")
    parser.add_argument("--gpu-output", type=Path, default=DATA_DIR / "convergence_gpu.csv")
    parser.add_argument("--sizes", type=int, nargs="+", default=DEFAULT_SIZES)
    args = parser.parse_args()

    print("CPU sweep:")
    cpu_rows = sweep(args.exe, args.sizes)
    write_csv(args.output, cpu_rows)
    print(f"Wrote {args.output}")

    if args.gpu_exe is not None:
        if not args.gpu_exe.exists():
            print(f"error: --gpu-exe {args.gpu_exe} does not exist", file=sys.stderr)
            sys.exit(1)

        print("GPU sweep:")
        gpu_rows = sweep(args.gpu_exe, args.sizes)
        write_csv(args.gpu_output, gpu_rows)
        print(f"Wrote {args.gpu_output}")

        cpu_order = fitted_order(cpu_rows, "cosine")
        gpu_order = fitted_order(gpu_rows, "cosine")
        print(
            f"Fitted eigenmode order over n<={ORDER_FIT_MAX_N}: "
            f"CPU={cpu_order:.3f}, GPU={gpu_order:.3f}"
        )
        # The global L2 error itself is a tiny (~1e-5) quantity, so single-precision
        # field differences between the backends are amplified into a few-percent gap
        # in the metric; the convergence order is the precision-robust thing to compare.
        if not 1.9 <= gpu_order <= 2.1:
            print(
                f"error: GPU eigenmode order {gpu_order:.3f} is not second-order (expected 1.9-2.1)",
                file=sys.stderr,
            )
            sys.exit(1)
        print("GPU backend reproduces second-order convergence.")


if __name__ == "__main__":
    main()
