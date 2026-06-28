# 3d-heat-solver

C++ solver for the heat equation in 3D, using an explicit (forward Euler) finite-difference scheme on a structured grid. Supports two execution backends from the same source tree:

- **CPU**: OpenMP-parallelized, SIMD-vectorized stencil loops.
- **GPU**: CUDA kernels, dispatched from the same `Integrator` classes via `#if defined(__CUDACC__)`.

Both backends live in the same `.cu`/`.cuh` files. CUDA support is optional; the project builds and runs fine with a plain C++ compiler if no CUDA toolchain is present.

## Paper

[`docs/paper.pdf`](docs/paper.pdf) is a short IEEE-style writeup of the project: the numerical method, the dual-backend design, the verification methodology, a real GPU boundary-condition bug it caught, and the performance results below with discussion.

To rebuild it completely: `pip install -r` [`docs/requirements.txt`](docs/requirements.txt), then run [`scripts/build-paper.ps1`](scripts/build-paper.ps1) or [`scripts/build-paper.sh`](scripts/build-paper.sh). That script regenerates the CSV inputs, figures, LaTeX tables, and `paper.pdf`. The profiling step calls [`scripts/profile.ps1`](scripts/profile.ps1) / [`scripts/profile.sh`](scripts/profile.sh) and must be run from an elevated shell since it needs GPU performance-counter access; use `-SkipProfile` or `--skip-profile` to rebuild from the existing Nsight CSV.

## Performance

Forward Euler integration + boundary update, 1000 steps, measured on this machine: mean ± sample stddev over 5 of 6 runs (first discarded as warm-up) via [`scripts/benchmark.ps1`](scripts/benchmark.ps1):

| Grid size | CPU (OpenMP/SIMD) | GPU (CUDA) | Speedup |
|-----------|-------------------|------------|---------|
| 8³        | 3.40 ± 0.70 ms     | 25.5 ± 5.9 ms | 0.13 ± 0.04x |
| 16³       | 12.6 ± 0.53 ms     | 34.4 ± 6.2 ms | 0.37 ± 0.07x |
| 32³       | 71.8 ± 1.4 ms      | 26.5 ± 6.4 ms | 2.71 ± 0.66x |
| 64³       | 518 ± 23 ms        | 28.4 ± 1.8 ms | 18.2 ± 1.4x  |
| 128³      | 3768 ± 50 ms       | 62.6 ± 0.6 ms | 60.2 ± 1.0x  |
| 256³      | 28910 ± 119 ms     | 444 ± 0.2 ms  | 65.1 ± 0.3x  |
| 512³      | 226716 ± 900 ms    | 3339 ± 1.0 ms | 67.9 ± 0.3x  |

At small grids, fixed CUDA kernel-launch overhead dominates and the GPU is slower than the CPU; the crossover is between 16³ and 32³. Past that, speedup climbs and settles around 60-68x as the GPU's bandwidth advantage takes over.

Nsight Compute profiling of the integration kernel, average of 5 runs (6 total, first discarded as warm-up) via [`scripts/profile.ps1`](scripts/profile.ps1):

| Grid size | DRAM % | SM util. % | L2 hit % | Occupancy % |
|-----------|--------|-----------|----------|--------------|
| 8³        | 0.8    | 0.2       | 85.1     | 27.5         |
| 16³       | 3.6    | 1.9       | 78.9     | 29.9         |
| 32³       | 11.5   | 13.3      | 76.5     | 41.5         |
| 64³       | 52.4   | 43.2      | 76.9     | 76.9         |
| 128³      | 82.9   | 50.4      | 78.4     | 77.1         |
| 256³      | 90.6   | 45.6      | 74.6     | 79.6         |
| 512³      | 91.1   | 45.5      | 74.6     | 78.9         |

DRAM throughput overtakes and pulls away from SM utilization beyond 64³, confirming the kernel is memory-bandwidth-bound rather than compute-bound. ("SM util." is `sm__throughput.avg.pct_of_peak_sustained_elapsed`, an aggregate over the SM's sub-units, not FP32 throughput specifically, so the actual FP32 fraction of peak is lower still.) At 8³/16³, both are under 4% with occupancy in the high 20s, consistent with fixed kernel-launch overhead, not data movement, dominating runtime at those sizes.

## Requirements

- CMake 3.24+
- A C++20 compiler (MSVC with the "Desktop development with C++" workload, or GCC/Clang)
- OpenMP (bundled with MSVC; `find_package(OpenMP)` elsewhere)
- Optional, for GPU acceleration: the CUDA Toolkit and a CUDA-capable GPU

## Building

From PowerShell, using the helper scripts in `scripts/`:

```powershell
.\scripts\run.ps1                       # CUDA float build (build/) + run
.\scripts\run.ps1 --double              # CUDA double build (build/) + run
.\scripts\run.ps1 --cuda-off            # CPU-only float build (build-nocuda/) + run
.\scripts\run.ps1 --cuda-off --double   # CPU-only double build (build-nocuda/) + run
```

or on a POSIX shell:

```bash
./scripts/run.sh
./scripts/run.sh --double
./scripts/run.sh --cuda-off
./scripts/run.sh --cuda-off --double
```

Both scripts configure and build via `vcvars64.bat` + CMake/Ninja, then run the resulting `heat_solver.exe`. Use `--precision float`, `--precision double`, `--float`, or `--double` to select the `Real` scalar type. Any extra arguments are forwarded to the executable, e.g. `.\scripts\run.ps1 --double --nx 128 --steps 500`.

Manually, from the project root:

```powershell
cmake -S . -B build
cmake --build build
.\build\heat_solver.exe
```

To force a CPU-only build (skips `nvcc` entirely, even if CUDA is installed):

```powershell
cmake -S . -B build-nocuda -DHEAT_SOLVER_ENABLE_CUDA=OFF
cmake --build build-nocuda
.\build-nocuda\heat_solver.exe
```

To switch the solver scalar type from the default `float` to `double`, configure with `-DHEAT_SOLVER_PRECISION=double` and rebuild. The central C++ type alias is `Real` in `src/utilities/real.cuh`.

## Configuration

Run with `--help` to see all options:

```
--nx <n> --ny <n> --nz <n>    grid size in each dimension (default 64)
--steps <n>                   total integration steps (default 1000)
--output-interval <n>         VTK output interval, 0 = disabled (default 0)
--ic <gaussian|cosine>        initial condition (default gaussian)
--alpha <f>                   thermal diffusivity (default 1.0)
--dx <f> --dy <f> --dz <f>    grid spacing (default 1.0)
```

`dt` isn't configurable; it's always derived from `alpha`/`dx`/`dy`/`dz` via the CFL stability limit, so the simulation can't be pushed into an unstable regime from the CLI.

## Testing

Tests live under [`tests/`](tests/) and run via CTest:

```powershell
cmake --build build
ctest --test-dir build --output-on-failure
```

- [`tests/physics.cpp`](tests/physics.cpp): peak value vs. the analytic Gaussian-diffusion solution, total-sum conservation under the insulated boundary, and exact ghost-cell mirroring (`du/dn = 0`) at every boundary face.
- [`tests/neumann.cpp`](tests/neumann.cpp): global L2 error against the exact finite-domain Neumann eigenfunction, a cosine product satisfying `du/dn = 0` on every face exactly, so it carries no infinite-domain modeling error.
- [`tests/config.cpp`](tests/config.cpp): CLI parsing, defaults, overrides, and that `dt` is always re-derived rather than left stale.
- [`tests/aligned_soa.cpp`](tests/aligned_soa.cpp): alignment-rounding math and zero-initialization of the underlying SoA storage.
- [`tests/initialization.cpp`](tests/initialization.cpp): zero-step Gaussian and cosine initialization over every grid point, including boundary/ghost layers.
- [`tests/convergence_order.cpp`](tests/convergence_order.cpp): lightweight cosine-eigenmode refinement check for approximately second-order convergence.
- CTest also includes expected-failure CLI validation checks for invalid grid size, diffusivity, and spacing.

The full CTest suite runs in both `build/` (CUDA, when a GPU is present) and `build-nocuda/` (CPU). GitHub Actions ([`.github/workflows/ci.yml`](.github/workflows/ci.yml)) runs the CPU test suite for both `float` and `double`; the CUDA backend gets float/double compile checks in CI, since GitHub-hosted runners have no GPU to execute CUDA kernels.

## Output

When `--output-interval` is nonzero, binary-format VTK files are written to `out/` (one per interval), viewable in ParaView or similar tools.
