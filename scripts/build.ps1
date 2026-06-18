param(
  [switch]$CudaOff
)

$cudaOff = $CudaOff -or ($args -contains '--cuda-off') -or ($args -contains '-cuda-off')

$buildDir = if ($cudaOff) { 'build-nocuda' } else { 'build' }
$cudaFlag = if ($cudaOff) { 'OFF' } else { 'ON' }

$vcvars = 'C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat'
$projectRoot = Split-Path -Parent $PSScriptRoot

Push-Location $projectRoot
try {
  cmd /c "`"$vcvars`" && cmake -S . -B $buildDir -G Ninja -DHEAT_SOLVER_ENABLE_CUDA=$cudaFlag && cmake --build $buildDir"
  if ($LASTEXITCODE -ne 0) { throw "Build failed with exit code $LASTEXITCODE" }
  Write-Host "Built: $projectRoot\$buildDir\heat_solver.exe"
} finally {
  Pop-Location
}
