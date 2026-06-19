$projectRoot = Split-Path -Parent $PSScriptRoot
$configPath = Join-Path $projectRoot 'src\config\config.hpp'
$originalConfig = Get-Content $configPath -Raw

$sizes = @(8, 16, 32, 64, 128, 256, 512)
$results = @()

function Set-GridSize($n) {
  $content = Get-Content $configPath -Raw
  $content = $content -replace 'std::size_t nx\{\d+\};', "std::size_t nx{$n};"
  $content = $content -replace 'std::size_t ny\{\d+\};', "std::size_t ny{$n};"
  $content = $content -replace 'std::size_t nz\{\d+\};', "std::size_t nz{$n};"
  Set-Content -Path $configPath -Value $content -NoNewline
}

function Run-Average($exePath) {
  $times = @()
  for ($i = 0; $i -lt 4; $i++) {
    $out = & $exePath
    $ms = [double]($out -replace 'ms', '')
    $times += $ms
  }
  # discard first run, average remaining 3
  $kept = $times[1..3]
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

try {
  foreach ($size in $sizes) {
    Write-Host "=== Grid size: ${size}^3 ===" -ForegroundColor Cyan
    Set-GridSize $size

    & "$PSScriptRoot\run.ps1" | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "CUDA build failed at size $size" }

    & "$PSScriptRoot\run.ps1" -CudaOff | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "No-CUDA build failed at size $size" }

    $gpuAvg = Run-Average "$projectRoot\build\heat_solver.exe"
    $cpuAvg = Run-Average "$projectRoot\build-nocuda\heat_solver.exe"
    $speedup = $cpuAvg / $gpuAvg

    $results += [PSCustomObject]@{
      Size    = "$size^3"
      CPU_ms  = Format-Sig3 $cpuAvg
      GPU_ms  = Format-Sig3 $gpuAvg
      Speedup = Format-Sig3 $speedup
    }

    Write-Host "CPU: $(Format-Sig3 $cpuAvg) ms | GPU: $(Format-Sig3 $gpuAvg) ms | Speedup: $(Format-Sig3 $speedup)x"
  }
} finally {
  Set-Content -Path $configPath -Value $originalConfig -NoNewline
  Write-Host "Restored original config.hpp" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "=== Summary ===" -ForegroundColor Green
$results | Format-Table -AutoSize
