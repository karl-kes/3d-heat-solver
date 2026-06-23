$projectRoot = Split-Path -Parent $PSScriptRoot

$sizes = @(8, 16, 32, 64, 128, 256, 512)
$steps = 1000
$results = @()

Write-Host "Building..." -ForegroundColor Cyan
& "$PSScriptRoot\run.ps1" --nx 8 --ny 8 --nz 8 --steps 1 --output-interval 0 | Out-Null
if ($LASTEXITCODE -ne 0) { throw "CUDA build failed" }

& "$PSScriptRoot\run.ps1" -CudaOff --nx 8 --ny 8 --nz 8 --steps 1 --output-interval 0 | Out-Null
if ($LASTEXITCODE -ne 0) { throw "No-CUDA build failed" }

function Run-Average($exePath, $size) {
  $times = @()
  for ($i = 0; $i -lt 6; $i++) {
    $out = & $exePath --nx $size --ny $size --nz $size --steps $steps --output-interval 0
    $ms = [double]($out -replace 'ms', '')
    $times += $ms
  }
  # discard first run, average remaining 5
  $kept = $times[1..5]
  $avg = ($kept | Measure-Object -Average).Average
  return $avg
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

  $gpuAvg = Run-Average "$projectRoot\build\heat_solver.exe" $size
  $cpuAvg = Run-Average "$projectRoot\build-nocuda\heat_solver.exe" $size
  $speedup = $cpuAvg / $gpuAvg

  $results += [PSCustomObject]@{
    Size    = "$size^3"
    CPU_ms  = Format-Sig3 $cpuAvg
    GPU_ms  = Format-Sig3 $gpuAvg
    Speedup = Format-Sig3 $speedup
  }

  Write-Host "CPU: $(Format-Sig3 $cpuAvg) ms | GPU: $(Format-Sig3 $gpuAvg) ms | Speedup: $(Format-Sig3 $speedup)x"
}

Write-Host ""
Write-Host "=== Summary ===" -ForegroundColor Green
$results | Format-Table -AutoSize
