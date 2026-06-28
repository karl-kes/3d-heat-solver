#!/usr/bin/env bash
set -euo pipefail

CUDA_FLAG=ON
PRECISION=float
FORWARDED_ARGS=()
while [ "$#" -gt 0 ]; do
  arg="$1"
  case "$arg" in
    --cuda-off|-cuda-off)
      CUDA_FLAG=OFF
      ;;
    --precision|-precision)
      shift
      if [ "$#" -eq 0 ]; then
        echo "missing value for $arg (expected float or double)" >&2
        exit 1
      fi
      PRECISION="$1"
      ;;
    --precision=*)
      PRECISION="${arg#--precision=}"
      ;;
    --float|-float)
      PRECISION=float
      ;;
    --double|-double)
      PRECISION=double
      ;;
    *)
      FORWARDED_ARGS+=("$arg")
      ;;
  esac
  shift
done

if [ "$PRECISION" != "float" ] && [ "$PRECISION" != "double" ]; then
  echo "invalid precision '$PRECISION' (expected float or double)" >&2
  exit 1
fi

if [ "$CUDA_FLAG" = "OFF" ]; then
  BUILD_DIR="build-nocuda"
else
  BUILD_DIR="build"
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

VCVARS='C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat'

cmd /c "\"$VCVARS\" && cmake -S . -B $BUILD_DIR -G Ninja -DHEAT_SOLVER_ENABLE_CUDA=$CUDA_FLAG -DHEAT_SOLVER_PRECISION=$PRECISION && cmake --build $BUILD_DIR"

echo "Built: $PROJECT_ROOT/$BUILD_DIR/heat_solver.exe ($PRECISION)"

"$PROJECT_ROOT/$BUILD_DIR/heat_solver.exe" "${FORWARDED_ARGS[@]}"
