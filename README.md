# 3d-heat-solver

C++ solver for the heat equation in 3D, using an explicit (forward Euler) finite-difference scheme on a structured grid. Supports two execution backends from the same source tree:

- **CPU** — OpenMP-parallelized, SIMD-vectorized stencil loops.
- **GPU** — CUDA kernels, dispatched from the same `Integrator` classes via `#if defined(__CUDACC__)`.

Both backends are kept in the same `.cu`/`.cuh` files; CUDA support is optional; the project builds and runs correctly with a plain C++ compiler if no CUDA toolchain is present.

## Requirements

- CMake 3.24+
- A C++17 compiler (MSVC, with the "Desktop development with C++" workload)
- OpenMP support (bundled with MSVC; `find_package(OpenMP)` elsewhere)
- (Optional, for GPU acceleration) the CUDA Toolkit and a CUDA-capable GPU

## Building

From an elevated/regular PowerShell, using the helper scripts in `scripts/`:

```powershell
.\scripts\run.ps1              # CUDA build (build/) + run
.\scripts\run.ps1 --cuda-off   # CPU-only build (build-nocuda/) + run
```

or on a POSIX shell:

```bash
./scripts/run.sh
./scripts/run.sh --cuda-off
```

Both scripts configure and build via `vcvars64.bat` + CMake/Ninja, then execute the resulting `heat_solver.exe`.

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

Simulation parameters (grid size, time step, total steps, output interval) are set in [`src/config/config.hpp`](src/config/config.hpp).

## Performance

Forward Euler integration + boundary condition update, 1000 steps, measured on this machine:

| Grid size | CPU (OpenMP/SIMD) | GPU (CUDA) | Speedup |
|-----------|-------------------|------------|---------|
| 8³        | ~3.08 ms          | ~18.1 ms   | ~0.170x |
| 16³       | ~13.6 ms          | ~14.5 ms   | ~0.944x |
| 32³       | ~74.7 ms          | ~23.0 ms   | ~3.25x  |
| 64³       | ~527 ms           | ~21.3 ms   | ~24.7x  |
| 128³      | ~3850 ms          | ~105 ms    | ~36.6x  |
| 256³      | ~29700 ms         | ~827 ms    | ~35.9x  |
| 512³      | ~229000 ms        | ~7210 ms   | ~31.8x  |

Each value is the average of 3 runs (total of 4, first run discarded as warm-up), via [`scripts/benchmark.ps1`](scripts/benchmark.ps1). At very small grids, fixed CUDA kernel-launch overhead dominates and the GPU is actually slower than the CPU; the crossover happens between 16³ and 32³. From there, speedup climbs and plateaus in the 30-37x range as both sides become bound by memory bandwidth rather than compute.

## Output

When `Config::output_interval` is nonzero, binary-format VTK files are written to `out/` (one per `output_interval` steps), viewable in ParaView or similar tools.
