param(
  [switch]$SkipBenchmark,
  [switch]$SkipProfile,
  [switch]$SkipConvergenceData,
  [switch]$SkipGpuCheck
)

$projectRoot = Split-Path -Parent $PSScriptRoot
$docsDir = Join-Path $projectRoot 'docs'

Push-Location $projectRoot
try {
  if (-not $SkipBenchmark) {
    & "$PSScriptRoot\benchmark.ps1"
    if ($LASTEXITCODE -ne 0) { throw "benchmark data generation failed" }
  }

  if (-not $SkipConvergenceData) {
    $vcvars = 'C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat'

    # Double-precision cosine sweep: isolates the n=256 single-precision floor.
    cmd /c "`"$vcvars`" && cmake -S . -B build-nocuda -G Ninja -DHEAT_SOLVER_ENABLE_CUDA=OFF -DHEAT_SOLVER_PRECISION=double && cmake --build build-nocuda"
    if ($LASTEXITCODE -ne 0) { throw "double-precision build failed" }
    python "docs/data/generate_convergence_data.py" --output "docs/data/convergence_fp64.csv"
    if ($LASTEXITCODE -ne 0) { throw "fp64 convergence data generation failed" }

    # Restore the default float build and regenerate the primary (fp32) sweep.
    cmd /c "`"$vcvars`" && cmake -S . -B build-nocuda -G Ninja -DHEAT_SOLVER_ENABLE_CUDA=OFF -DHEAT_SOLVER_PRECISION=float && cmake --build build-nocuda"
    if ($LASTEXITCODE -ne 0) { throw "float-precision build failed" }

    if ($SkipGpuCheck) {
      python "docs/data/generate_convergence_data.py"
      if ($LASTEXITCODE -ne 0) { throw "fp32 convergence data generation failed" }
    } else {
      # CUDA (fp32) build: verify the GPU backend reproduces the CPU sweep's second-order convergence.
      cmd /c "`"$vcvars`" && cmake -S . -B build -G Ninja -DHEAT_SOLVER_PRECISION=float && cmake --build build --target convergence_probe"
      if ($LASTEXITCODE -ne 0) { throw "CUDA float build failed" }
      python "docs/data/generate_convergence_data.py" --gpu-exe "build/convergence_probe.exe"
      if ($LASTEXITCODE -ne 0) { throw "fp32 convergence data generation / GPU convergence check failed" }
    }
  }

  if (-not $SkipProfile) {
    & "$PSScriptRoot\profile.ps1"
    if ($LASTEXITCODE -ne 0) { throw "profile data generation failed" }
  }

  python "docs/data/generate_plots.py"
  if ($LASTEXITCODE -ne 0) { throw "runtime/speedup plot generation failed" }

  python "docs/data/convergence.py"
  if ($LASTEXITCODE -ne 0) { throw "convergence plot generation failed" }

  python "docs/data/ncu_plots.py"
  if ($LASTEXITCODE -ne 0) { throw "Nsight plot generation failed" }

  Push-Location $docsDir
  try {
    pdflatex -interaction=nonstopmode -halt-on-error paper.tex
    if ($LASTEXITCODE -ne 0) { throw "first pdflatex pass failed" }
    pdflatex -interaction=nonstopmode -halt-on-error paper.tex
    if ($LASTEXITCODE -ne 0) { throw "second pdflatex pass failed" }
  } finally {
    Pop-Location
  }
} finally {
  Pop-Location
}

Write-Host "Built $docsDir\paper.pdf" -ForegroundColor Green
