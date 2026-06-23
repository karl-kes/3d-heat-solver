#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

SIZES=(8 16 32 64 128 256 512)
STEPS=1000

echo "Building..."
"$SCRIPT_DIR/run.sh" --nx 8 --ny 8 --nz 8 --steps 1 --output-interval 0 > /dev/null
"$SCRIPT_DIR/run.sh" --cuda-off --nx 8 --ny 8 --nz 8 --steps 1 --output-interval 0 > /dev/null

# Runs the exe 6 times at the given grid size, discards the first, averages the remaining 5.
run_average() {
  local exe_path="$1"
  local size="$2"
  local times=()
  for i in 1 2 3 4 5 6; do
    local out
    out="$("$exe_path" --nx "$size" --ny "$size" --nz "$size" --steps "$STEPS" --output-interval 0)"
    local ms="${out%ms}"
    times+=("$ms")
  done
  awk -v a="${times[1]}" -v b="${times[2]}" -v c="${times[3]}" -v d="${times[4]}" -v e="${times[5]}" \
    'BEGIN { printf "%.10f", (a+b+c+d+e)/5 }'
}

# Rounds a value to 3 significant figures.
format_sig3() {
  local value="$1"
  awk -v v="$value" 'BEGIN {
    if (v == 0) { printf "0.00"; exit }
    av = v < 0 ? -v : v
    digits = int(log(av) / log(10))
    decimals = 2 - digits
    if (decimals < 0) { decimals = 0 }
    printf "%.*f", decimals, v
  }'
}

declare -a SUMMARY=()

for size in "${SIZES[@]}"; do
  echo "=== Grid size: ${size}^3 ==="

  gpu_avg="$(run_average "$PROJECT_ROOT/build/heat_solver.exe" "$size")"
  cpu_avg="$(run_average "$PROJECT_ROOT/build-nocuda/heat_solver.exe" "$size")"
  speedup="$(awk -v c="$cpu_avg" -v g="$gpu_avg" 'BEGIN { printf "%.10f", c/g }')"

  cpu_fmt="$(format_sig3 "$cpu_avg")"
  gpu_fmt="$(format_sig3 "$gpu_avg")"
  speedup_fmt="$(format_sig3 "$speedup")"

  SUMMARY+=("${size}^3 | ${cpu_fmt} ms | ${gpu_fmt} ms | ${speedup_fmt}x")

  echo "CPU: ${cpu_fmt} ms | GPU: ${gpu_fmt} ms | Speedup: ${speedup_fmt}x"
done

echo ""
echo "=== Summary ==="
printf '%s\n' "${SUMMARY[@]}"
