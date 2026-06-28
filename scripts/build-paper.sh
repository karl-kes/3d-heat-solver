#!/usr/bin/env bash
set -euo pipefail

SKIP_BENCHMARK=0
SKIP_PROFILE=0
SKIP_CONVERGENCE_DATA=0
SKIP_GPU_CHECK=0

for arg in "$@"; do
  case "$arg" in
    --skip-benchmark)
      SKIP_BENCHMARK=1
      ;;
    --skip-profile)
      SKIP_PROFILE=1
      ;;
    --skip-convergence-data)
      SKIP_CONVERGENCE_DATA=1
      ;;
    --skip-gpu-check)
      SKIP_GPU_CHECK=1
      ;;
    *)
      echo "unknown option: $arg" >&2
      echo "usage: $0 [--skip-benchmark] [--skip-profile] [--skip-convergence-data] [--skip-gpu-check]" >&2
      exit 1
      ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DOCS_DIR="$PROJECT_ROOT/docs"

cd "$PROJECT_ROOT"

if [ "$SKIP_BENCHMARK" -eq 0 ]; then
  "$SCRIPT_DIR/benchmark.sh"
fi

if [ "$SKIP_CONVERGENCE_DATA" -eq 0 ]; then
  VCVARS='C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat'

  # Double-precision cosine sweep: isolates the n=256 single-precision floor.
  cmd /c "\"$VCVARS\" && cmake -S . -B build-nocuda -G Ninja -DHEAT_SOLVER_ENABLE_CUDA=OFF -DHEAT_SOLVER_PRECISION=double && cmake --build build-nocuda"
  python docs/data/generate_convergence_data.py --output docs/data/convergence_fp64.csv

  # Restore the default float build and regenerate the primary (fp32) sweep.
  cmd /c "\"$VCVARS\" && cmake -S . -B build-nocuda -G Ninja -DHEAT_SOLVER_ENABLE_CUDA=OFF -DHEAT_SOLVER_PRECISION=float && cmake --build build-nocuda"

  if [ "$SKIP_GPU_CHECK" -eq 0 ]; then
    # CUDA (fp32) build: verify the GPU backend reproduces the CPU sweep's second-order convergence.
    cmd /c "\"$VCVARS\" && cmake -S . -B build -G Ninja -DHEAT_SOLVER_PRECISION=float && cmake --build build --target convergence_probe"
    python docs/data/generate_convergence_data.py --gpu-exe build/convergence_probe.exe
  else
    python docs/data/generate_convergence_data.py
  fi
fi

if [ "$SKIP_PROFILE" -eq 0 ]; then
  "$SCRIPT_DIR/profile.sh"
fi

python docs/data/generate_plots.py
python docs/data/convergence.py
python docs/data/ncu_plots.py

(
  cd "$DOCS_DIR"
  pdflatex -interaction=nonstopmode -halt-on-error paper.tex
  pdflatex -interaction=nonstopmode -halt-on-error paper.tex
)

echo "Built $DOCS_DIR/paper.pdf"
