$projectRoot = Split-Path -Parent $PSScriptRoot
$ncu = "C:\Program Files\NVIDIA Corporation\Nsight Compute 2026.2.0\ncu.bat"
$exe = "$projectRoot\build\heat_solver.exe"

$sizes = @(8, 16, 32, 64, 128, 256, 512)
$metrics = "dram__throughput.avg.pct_of_peak_sustained_elapsed,sm__throughput.avg.pct_of_peak_sustained_elapsed,lts__t_sector_hit_rate.pct,sm__warps_active.avg.pct_of_peak_sustained_active,gpu__time_duration.sum"
$results = @()
$csvRows = @()
$csvPath = Join-Path $projectRoot 'docs/data/ncu.csv'

Write-Host "Building..." -ForegroundColor Cyan
& "$PSScriptRoot\run.ps1" --nx 8 --ny 8 --nz 8 --steps 1 --output-interval 0 | Out-Null
if ($LASTEXITCODE -ne 0) { throw "CUDA build failed" }

function Get-NcuSample($size) {
  $output = & $ncu --kernel-name gpuIntegrateGridKernel --launch-skip 2 --launch-count 1 `
    --metrics $metrics --csv $exe --nx $size --ny $size --nz $size --steps 5 --output-interval 0 2>&1

  $csvLines = $output | Where-Object { $_ -match '^"' }
  $rows = $csvLines | ConvertFrom-Csv

  if ($rows.Count -eq 0) {
    Write-Host ($output -join "`n")
    throw "ncu produced no metric rows for size $size -- likely ERR_NVGPUCTRPERM. Run this script from an elevated (Administrator) PowerShell."
  }

  $sample = @{}
  foreach ($row in $rows) {
    $sample[$row.'Metric Name'] = [double]($row.'Metric Value' -replace ',', '')
  }
  return $sample
}

function Get-Stats($values) {
  $mean = ($values | Measure-Object -Average).Average
  $variance = ($values | ForEach-Object { ($_ - $mean) * ($_ - $mean) } | Measure-Object -Sum).Sum / ($values.Count - 1)
  return [PSCustomObject]@{ Mean = $mean; StdDev = [math]::Sqrt($variance) }
}

function Get-NcuStats($size) {
  $samples = @()
  for ($i = 0; $i -lt 6; $i++) {
    $samples += Get-NcuSample $size
  }
  # discard first run, compute mean/stddev over remaining 5
  $kept = $samples[1..5]

  $stats = @{}
  foreach ($key in $kept[0].Keys) {
    $stats[$key] = Get-Stats ($kept | ForEach-Object { $_[$key] })
  }
  return $stats
}

foreach ($size in $sizes) {
  Write-Host "=== Grid size: ${size}^3 ===" -ForegroundColor Cyan

  $stats = Get-NcuStats $size
  $dram = $stats["dram__throughput.avg.pct_of_peak_sustained_elapsed"]
  $compute = $stats["sm__throughput.avg.pct_of_peak_sustained_elapsed"]
  $l2 = $stats["lts__t_sector_hit_rate.pct"]
  $occ = $stats["sm__warps_active.avg.pct_of_peak_sustained_active"]
  $dur = $stats["gpu__time_duration.sum"]

  $row = [PSCustomObject]@{
    Size            = "$size^3"
    DRAM_pct        = [math]::Round($dram.Mean, 2)
    DRAM_StdDev     = [math]::Round($dram.StdDev, 2)
    Compute_pct     = [math]::Round($compute.Mean, 2)
    Compute_StdDev  = [math]::Round($compute.StdDev, 2)
    L2Hit_pct       = [math]::Round($l2.Mean, 2)
    L2Hit_StdDev    = [math]::Round($l2.StdDev, 2)
    Occupancy_pct   = [math]::Round($occ.Mean, 2)
    Occupancy_StdDev = [math]::Round($occ.StdDev, 2)
    Duration_ns     = [math]::Round($dur.Mean, 1)
    Duration_StdDev = [math]::Round($dur.StdDev, 1)
  }
  $results += $row

  $csvRows += [PSCustomObject]@{
    nx = $size
    dram_pct = $dram.Mean
    dram_std = $dram.StdDev
    sm_pct = $compute.Mean
    sm_std = $compute.StdDev
    l2_hit_pct = $l2.Mean
    l2_hit_std = $l2.StdDev
    occupancy_pct = $occ.Mean
    occupancy_std = $occ.StdDev
    duration_ns = $dur.Mean
  }

  Write-Host ("DRAM: {0} +/- {1}% | Compute: {2} +/- {3}% | L2 hit: {4} +/- {5}% | Occupancy: {6} +/- {7}% | Duration: {8} +/- {9} ns" -f `
    $row.DRAM_pct, $row.DRAM_StdDev, $row.Compute_pct, $row.Compute_StdDev, `
    $row.L2Hit_pct, $row.L2Hit_StdDev, $row.Occupancy_pct, $row.Occupancy_StdDev, `
    $row.Duration_ns, $row.Duration_StdDev)
}

Write-Host ""
Write-Host "=== Summary ===" -ForegroundColor Green
$results | Format-Table -AutoSize

New-Item -ItemType Directory -Force -Path (Split-Path -Parent $csvPath) | Out-Null
$csvRows | ConvertTo-Csv -NoTypeInformation | ForEach-Object { $_ -replace '"', '' } | Set-Content -Encoding ASCII $csvPath
Write-Host "Wrote $csvPath" -ForegroundColor Green
