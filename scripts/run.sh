#!/usr/bin/env bash
set -euo pipefail

CUDA_FLAG=ON
FORWARDED_ARGS=()
for arg in "$@"; do
  case "$arg" in
    --cuda-off|-cuda-off)
      CUDA_FLAG=OFF
      ;;
    *)
      FORWARDED_ARGS+=("$arg")
      ;;
  esac
done

if [ "$CUDA_FLAG" = "OFF" ]; then
  BUILD_DIR="build-nocuda"
else
  BUILD_DIR="build"
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

VCVARS='C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat'

cmd /c "\"$VCVARS\" && cmake -S . -B $BUILD_DIR -G Ninja -DHEAT_SOLVER_ENABLE_CUDA=$CUDA_FLAG && cmake --build $BUILD_DIR"

echo "Built: $PROJECT_ROOT/$BUILD_DIR/heat_solver.exe"

"$PROJECT_ROOT/$BUILD_DIR/heat_solver.exe" "${FORWARDED_ARGS[@]}"
