#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG_PATH="$PROJECT_ROOT/src/config/config.hpp"

ORIGINAL_CONFIG="$(cat "$CONFIG_PATH")"

restore_config() {
  printf '%s' "$ORIGINAL_CONFIG" > "$CONFIG_PATH"
  echo "Restored original config.hpp"
}
trap restore_config EXIT

SIZES=(8 16 32 64 128 256 512)

set_grid_size() {
  local n="$1"
  sed -i -E \
    -e "s/std::size_t nx\{[0-9]+\};/std::size_t nx{$n};/" \
    -e "s/std::size_t ny\{[0-9]+\};/std::size_t ny{$n};/" \
    -e "s/std::size_t nz\{[0-9]+\};/std::size_t nz{$n};/" \
    "$CONFIG_PATH"
}

# Runs the exe 4 times, discards the first, averages the remaining 3.
run_average() {
  local exe_path="$1"
  local times=()
  for i in 1 2 3 4; do
    local out
    out="$("$exe_path")"
    local ms="${out%ms}"
    times+=("$ms")
  done
  awk -v a="${times[1]}" -v b="${times[2]}" -v c="${times[3]}" 'BEGIN { printf "%.10f", (a+b+c)/3 }'
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
  set_grid_size "$size"

  "$SCRIPT_DIR/run.sh" > /dev/null
  "$SCRIPT_DIR/run.sh" --cuda-off > /dev/null

  gpu_avg="$(run_average "$PROJECT_ROOT/build/heat_solver.exe")"
  cpu_avg="$(run_average "$PROJECT_ROOT/build-nocuda/heat_solver.exe")"
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
