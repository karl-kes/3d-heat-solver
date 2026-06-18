# 3d-heat-solver

C++ solver for the heat equation in 3D, using an explicit (forward Euler) finite-difference scheme on a structured grid. Supports two execution backends from the same source tree:

- **CPU** — OpenMP-parallelized, SIMD-vectorized stencil loops.
- **GPU** — CUDA kernels, dispatched from the same `Integrator` classes via `#if defined(__CUDACC__)`.

Both backends are kept in the same `.cu`/`.cuh` files; CUDA support is optional — the project builds and runs correctly with a plain C++ compiler if no CUDA toolchain is present.

## Requirements

- CMake 3.24+
- A C++17 compiler (MSVC, with the "Desktop development with C++" workload)
- OpenMP support (bundled with MSVC; `find_package(OpenMP)` elsewhere)
- (Optional, for GPU acceleration) the CUDA Toolkit and a CUDA-capable GPU

## Building

From an elevated/regular PowerShell, using the helper scripts in `scripts/`:

```powershell
.\scripts\build.ps1              # CUDA build (build/)
.\scripts\build.ps1 --cuda-off   # CPU-only build (build-nocuda/)
```

or on a POSIX shell:

```bash
./scripts/build.sh
./scripts/build.sh --cuda-off
```

Both scripts configure and build via `vcvars64.bat` + CMake/Ninja, and print the path to the resulting `heat_solver.exe`.

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
| 128³      | ~1096 ms          | ~62 ms     | ~17.6x  |
| 256³      | ~10.1 s           | ~417 ms    | ~24x    |
| 512³      | ~655 s            | ~3.5 s     | ~185x   |

The speedup grows with grid size: once the working set exceeds CPU cache, the CPU path becomes bound by DRAM bandwidth, while the GPU's much higher memory bandwidth keeps scaling.

## Output

When `Config::output_interval` is nonzero, binary-format VTK files are written to `out/` (one per `output_interval` steps), viewable in ParaView or similar tools.
