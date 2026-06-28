$cudaOff = $false
$precision = 'float'
$forwardedArgs = @()

for ($i = 0; $i -lt $args.Count; ++$i) {
  $arg = $args[$i]
  if ($arg -eq '--cuda-off' -or $arg -eq '-cuda-off' -or $arg -eq '-CudaOff') {
    $cudaOff = $true
    continue
  } elseif ($arg -eq '--precision' -or $arg -eq '-precision') {
    if ($i + 1 -ge $args.Count) { throw "missing value for $arg (expected float or double)" }
    $precision = $args[++$i]
  } elseif ($arg -like '--precision=*') {
    $precision = $arg.Substring('--precision='.Length)
  } elseif ($arg -eq '--float' -or $arg -eq '-float') {
    $precision = 'float'
  } elseif ($arg -eq '--double' -or $arg -eq '-double') {
    $precision = 'double'
  } else {
    $forwardedArgs += $arg
  }
}

if ($precision -ne 'float' -and $precision -ne 'double') {
  throw "invalid precision '$precision' (expected float or double)"
}

$buildDir = if ($cudaOff) { 'build-nocuda' } else { 'build' }
$cudaFlag = if ($cudaOff) { 'OFF' } else { 'ON' }

$vcvars = 'C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat'
$projectRoot = Split-Path -Parent $PSScriptRoot

Push-Location $projectRoot
try {
  cmd /c "`"$vcvars`" && cmake -S . -B $buildDir -G Ninja -DHEAT_SOLVER_ENABLE_CUDA=$cudaFlag -DHEAT_SOLVER_PRECISION=$precision && cmake --build $buildDir"
  if ($LASTEXITCODE -ne 0) { throw "Build failed with exit code $LASTEXITCODE" }
  Write-Host "Built: $projectRoot\$buildDir\heat_solver.exe ($precision)"

  & "$projectRoot\$buildDir\heat_solver.exe" @forwardedArgs
  if ($LASTEXITCODE -ne 0) { throw "Run failed with exit code $LASTEXITCODE" }
} finally {
  Pop-Location
}
