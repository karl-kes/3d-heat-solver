# 3d-heat-solver

C++ solver for the heat equation in 3D, using an explicit (forward Euler) finite-difference scheme on a structured grid. Supports two execution backends from the same source tree:

- **CPU**: OpenMP-parallelized, SIMD-vectorized stencil loops.
- **GPU**: CUDA kernels, dispatched from the same `Integrator` classes via `#if defined(__CUDACC__)`.

Both backends live in the same `.cu`/`.cuh` files. CUDA support is optional; the project builds and runs fine with a plain C++ compiler if no CUDA toolchain is present.

## Requirements

- CMake 3.24+
- A C++20 compiler (MSVC with the "Desktop development with C++" workload, or GCC/Clang)
- OpenMP (bundled with MSVC; `find_package(OpenMP)` elsewhere)
- Optional, for GPU acceleration: the CUDA Toolkit and a CUDA-capable GPU

## Building

From PowerShell, using the helper scripts in `scripts/`:

```powershell
.\scripts\run.ps1              # CUDA build (build/) + run
.\scripts\run.ps1 --cuda-off   # CPU-only build (build-nocuda/) + run
```

or on a POSIX shell:

```bash
./scripts/run.sh
./scripts/run.sh --cuda-off
```

Both scripts configure and build via `vcvars64.bat` + CMake/Ninja, then run the resulting `heat_solver.exe`. Any extra arguments are forwarded to the executable, e.g. `.\scripts\run.ps1 --nx 128 --steps 500`.

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

## Configuration

Run with `--help` to see all options:

```
--nx <n> --ny <n> --nz <n>    grid size in each dimension (default 64)
--steps <n>                   total integration steps (default 1000)
--output-interval <n>         VTK output interval, 0 = disabled (default 0)
--alpha <f>                   thermal diffusivity (default 1.0)
--dx <f> --dy <f> --dz <f>    grid spacing (default 1.0)
```

`dt` isn't configurable; it's always derived from `alpha`/`dx`/`dy`/`dz` via the CFL stability limit, so the simulation can't be pushed into an unstable regime from the CLI.

## Performance

Forward Euler integration + boundary update, 1000 steps, measured on this machine, average of 5 runs (6 total, first discarded as warm-up) via [`scripts/benchmark.ps1`](scripts/benchmark.ps1):

| Grid size | CPU (OpenMP/SIMD) | GPU (CUDA) | Speedup |
|-----------|-------------------|------------|---------|
| 8³        | ~4.14 ms          | ~32.2 ms   | ~0.13x  |
| 16³       | ~13.8 ms          | ~22.7 ms   | ~0.61x  |
| 32³       | ~83.7 ms          | ~26.7 ms   | ~3.13x  |
| 64³       | ~535 ms           | ~31.8 ms   | ~16.8x  |
| 128³      | ~3805 ms          | ~62.0 ms   | ~61.4x  |
| 256³      | ~29856 ms         | ~446 ms    | ~67.0x  |
| 512³      | ~225321 ms        | ~3336 ms   | ~67.6x  |

At small grids, fixed CUDA kernel-launch overhead dominates and the GPU is slower than the CPU; the crossover is between 16³ and 32³. Past that, speedup climbs and settles around 60-70x as the GPU's bandwidth advantage takes over.

## Testing

Tests live under [`tests/`](tests/) and run via CTest:

```powershell
cmake --build build
ctest --test-dir build --output-on-failure
```

- [`tests/physics.cpp`](tests/physics.cpp): peak value vs. the analytic Gaussian-diffusion solution, total-sum conservation under the insulated boundary, and exact ghost-cell mirroring (`du/dn = 0`) at every boundary face.
- [`tests/config.cpp`](tests/config.cpp): CLI parsing, defaults, overrides, and that `dt` is always re-derived rather than left stale.
- [`tests/aligned_soa.cpp`](tests/aligned_soa.cpp): alignment-rounding math and zero-initialization of the underlying SoA storage.

`physics` runs in both `build/` (CUDA) and `build-nocuda/` (CPU). Since each independently checks against the known-correct analytic solution, both passing also serves as the CPU/GPU parity check. GitHub Actions ([`.github/workflows/ci.yml`](.github/workflows/ci.yml)) runs this for real on the CPU backend; the CUDA backend only gets a compile check in CI, since GitHub-hosted runners have no GPU to run it on.

## Output

When `--output-interval` is nonzero, binary-format VTK files are written to `out/` (one per interval), viewable in ParaView or similar tools.
