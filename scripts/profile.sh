#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

NCU="/c/Program Files/NVIDIA Corporation/Nsight Compute 2026.2.0/ncu.bat"
EXE="$PROJECT_ROOT/build/heat_solver.exe"
METRICS="dram__throughput.avg.pct_of_peak_sustained_elapsed,sm__throughput.avg.pct_of_peak_sustained_elapsed,lts__t_sector_hit_rate.pct,sm__warps_active.avg.pct_of_peak_sustained_active,gpu__time_duration.sum"

SIZES=(8 16 32 64 128 256 512)

echo "Building..."
"$SCRIPT_DIR/run.sh" --nx 8 --ny 8 --nz 8 --steps 1 --output-interval 0 > /dev/null

get_ncu_sample() {
  local size="$1"
  local output
  output="$("$NCU" --kernel-name gpuIntegrateGridKernel --launch-skip 2 --launch-count 1 \
    --metrics "$METRICS" --csv "$EXE" --nx "$size" --ny "$size" --nz "$size" \
    --steps 5 --output-interval 0 2>&1)" || true

  local csv_lines
  csv_lines="$(echo "$output" | grep '^"' || true)"

  if [ -z "$csv_lines" ]; then
    echo "$output" >&2
    echo "ncu produced no metric rows for size $size -- likely ERR_NVGPUCTRPERM. Run this script from an elevated/admin shell." >&2
    exit 1
  fi

  local data_lines
  data_lines="$(echo "$csv_lines" | tail -n +2)"

  local extract
  extract() { echo "$1" | grep -oE '"[^"]*"$' | tr -d '",'; }

  DRAM="$(extract "$(echo "$data_lines" | sed -n '1p')")"
  DURATION="$(extract "$(echo "$data_lines" | sed -n '2p')")"
  L2HIT="$(extract "$(echo "$data_lines" | sed -n '3p')")"
  COMPUTE="$(extract "$(echo "$data_lines" | sed -n '4p')")"
  OCCUPANCY="$(extract "$(echo "$data_lines" | sed -n '5p')")"
}

# Mean and sample stddev of 5 values, printed as "mean stddev".
mean_stddev() {
  awk -v a="$1" -v b="$2" -v c="$3" -v d="$4" -v e="$5" 'BEGIN {
    mean = (a+b+c+d+e)/5
    var = ((a-mean)^2 + (b-mean)^2 + (c-mean)^2 + (d-mean)^2 + (e-mean)^2) / 4
    printf "%.4f %.4f", mean, sqrt(var)
  }'
}

declare -a SUMMARY=()

for size in "${SIZES[@]}"; do
  echo "=== Grid size: ${size}^3 ==="

  dram_vals=() compute_vals=() l2_vals=() occ_vals=() dur_vals=()
  for i in 1 2 3 4 5 6; do
    get_ncu_sample "$size"
    dram_vals+=("$DRAM")
    compute_vals+=("$COMPUTE")
    l2_vals+=("$L2HIT")
    occ_vals+=("$OCCUPANCY")
    dur_vals+=("$DURATION")
  done

  # discard first run (index 0), keep indices 1-5
  read -r dram_mean dram_std <<< "$(mean_stddev "${dram_vals[@]:1:5}")"
  read -r compute_mean compute_std <<< "$(mean_stddev "${compute_vals[@]:1:5}")"
  read -r l2_mean l2_std <<< "$(mean_stddev "${l2_vals[@]:1:5}")"
  read -r occ_mean occ_std <<< "$(mean_stddev "${occ_vals[@]:1:5}")"
  read -r dur_mean dur_std <<< "$(mean_stddev "${dur_vals[@]:1:5}")"

  SUMMARY+=("${size}^3 | DRAM ${dram_mean}+/-${dram_std}% | Compute ${compute_mean}+/-${compute_std}% | L2 hit ${l2_mean}+/-${l2_std}% | Occupancy ${occ_mean}+/-${occ_std}% | Duration ${dur_mean}+/-${dur_std}ns")

  echo "DRAM: ${dram_mean} +/- ${dram_std}% | Compute: ${compute_mean} +/- ${compute_std}% | L2 hit: ${l2_mean} +/- ${l2_std}% | Occupancy: ${occ_mean} +/- ${occ_std}% | Duration: ${dur_mean} +/- ${dur_std} ns"
done

echo ""
echo "=== Summary ==="
printf '%s\n' "${SUMMARY[@]}"
