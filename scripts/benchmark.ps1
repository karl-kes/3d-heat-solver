$projectRoot = Split-Path -Parent $PSScriptRoot

$sizes = @(8, 16, 32, 64, 128, 256, 512)
$steps = 1000
$results = @()
$csvRows = @()
$csvPath = Join-Path $projectRoot 'docs/data/benchmark.csv'

Write-Host "Building..." -ForegroundColor Cyan
& "$PSScriptRoot\run.ps1" --nx 8 --ny 8 --nz 8 --steps 1 --output-interval 0 | Out-Null
if ($LASTEXITCODE -ne 0) { throw "CUDA build failed" }

& "$PSScriptRoot\run.ps1" -CudaOff --nx 8 --ny 8 --nz 8 --steps 1 --output-interval 0 | Out-Null
if ($LASTEXITCODE -ne 0) { throw "No-CUDA build failed" }

function Get-Stats($values) {
  $mean = ($values | Measure-Object -Average).Average
  $variance = ($values | ForEach-Object { ($_ - $mean) * ($_ - $mean) } | Measure-Object -Sum).Sum / ($values.Count - 1)
  return [PSCustomObject]@{ Mean = $mean; StdDev = [math]::Sqrt($variance) }
}

function Run-Average($exePath, $size) {
  $times = @()
  for ($i = 0; $i -lt 6; $i++) {
    $out = & $exePath --nx $size --ny $size --nz $size --steps $steps --output-interval 0
    $ms = [double]($out -replace 'ms', '')
    $times += $ms
  }
  # discard first run, compute mean/stddev over remaining 5
  return Get-Stats $times[1..5]
}

function Format-Sig3($value) {
  if ($value -eq 0) { return "0.00" }
  $digits = [math]::Floor([math]::Log10([math]::Abs($value)))
  $decimals = 2 - $digits
  if ($decimals -lt 0) { $decimals = 0 }
  return [math]::Round($value, $decimals).ToString("F$decimals")
}

foreach ($size in $sizes) {
  Write-Host "=== Grid size: ${size}^3 ===" -ForegroundColor Cyan

  $gpu = Run-Average "$projectRoot\build\heat_solver.exe" $size
  $cpu = Run-Average "$projectRoot\build-nocuda\heat_solver.exe" $size
  $speedup = $cpu.Mean / $gpu.Mean
  # standard error propagation for a ratio of two independent quantities
  $speedupStdDev = $speedup * [math]::Sqrt(
    [math]::Pow($cpu.StdDev / $cpu.Mean, 2) + [math]::Pow($gpu.StdDev / $gpu.Mean, 2)
  )

  $results += [PSCustomObject]@{
    Size       = "$size^3"
    CPU_ms     = Format-Sig3 $cpu.Mean
    CPU_StdDev = Format-Sig3 $cpu.StdDev
    GPU_ms     = Format-Sig3 $gpu.Mean
    GPU_StdDev = Format-Sig3 $gpu.StdDev
    Speedup    = Format-Sig3 $speedup
    Speedup_StdDev = Format-Sig3 $speedupStdDev
  }

  $csvRows += [PSCustomObject]@{
    size = $size
    cpu_ms = $cpu.Mean
    cpu_std = $cpu.StdDev
    gpu_ms = $gpu.Mean
    gpu_std = $gpu.StdDev
  }

  Write-Host "CPU: $(Format-Sig3 $cpu.Mean) +/- $(Format-Sig3 $cpu.StdDev) ms | GPU: $(Format-Sig3 $gpu.Mean) +/- $(Format-Sig3 $gpu.StdDev) ms | Speedup: $(Format-Sig3 $speedup) +/- $(Format-Sig3 $speedupStdDev)x"
}

Write-Host ""
Write-Host "=== Summary ===" -ForegroundColor Green
$results | Format-Table -AutoSize

New-Item -ItemType Directory -Force -Path (Split-Path -Parent $csvPath) | Out-Null
$csvRows | ConvertTo-Csv -NoTypeInformation | ForEach-Object { $_ -replace '"', '' } | Set-Content -Encoding ASCII $csvPath
Write-Host "Wrote $csvPath" -ForegroundColor Green
