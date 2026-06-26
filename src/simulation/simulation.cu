#include "simulation.hpp"
#include "../utilities/helpers.cuh"
#include "../io/vtk_writer.hpp"

#include <cmath>

Simulation::Simulation(const Config& config)
: total_steps_{config.total_steps}
, output_interval_{config.output_interval}
, ic_{config.ic}
, grid_a_{config}
, grid_b_{config}
, integrator_{std::make_unique<ExplicitEuler>(config)}
{ initialize(); }

namespace {

#if defined(__CUDACC__)
__global__
void gpuInitializeGaussianKernel(
  std::size_t nx, std::size_t ny, std::size_t nz,
  std::size_t p_nx, std::size_t p_ny,
  float* RESTRICT u
) {
  const std::size_t i{blockIdx.x * blockDim.x + threadIdx.x};
  const std::size_t j{blockIdx.y * blockDim.y + threadIdx.y};
  const std::size_t k{blockIdx.z * blockDim.z + threadIdx.z};

  if (i >= nx || j >= ny || k >= nz) { return; }

  const float center_x{0.5f * static_cast<float>(nx - 1)};
  const float center_y{0.5f * static_cast<float>(ny - 1)};
  const float center_z{0.5f * static_cast<float>(nz - 1)};

  const float amplitude{1.0f};
  const float sigma{0.1f * static_cast<float>(nx)};
  const float two_sigma_sq{2.0f * sigma * sigma};
  const float inv_two_sig_sq{1.0f / two_sigma_sq};

  const float rx{static_cast<float>(i) - center_x};
  const float ry{static_cast<float>(j) - center_y};
  const float rz{static_cast<float>(k) - center_z};
  const float r_sq{rx*rx + ry*ry + rz*rz};

  const std::size_t point{i + p_nx * (j + p_ny * k)};
  u[point] = amplitude * expf(-r_sq * inv_two_sig_sq);
}

__global__
void gpuInitializeCosineKernel(
  std::size_t nx, std::size_t ny, std::size_t nz,
  std::size_t p_nx, std::size_t p_ny,
  float* RESTRICT u
) {
  const std::size_t i{blockIdx.x * blockDim.x + threadIdx.x};
  const std::size_t j{blockIdx.y * blockDim.y + threadIdx.y};
  const std::size_t k{blockIdx.z * blockDim.z + threadIdx.z};

  if (i >= nx || j >= ny || k >= nz) { return; }

  const std::size_t point{i + p_nx * (j + p_ny * k)};
  u[point] = cosine_mode(i, nx) * cosine_mode(j, ny) * cosine_mode(k, nz);
}
#else
  void cpuInitializeGaussianKernel(
  std::size_t nx, std::size_t ny, std::size_t nz,
  std::size_t p_nx, std::size_t p_ny,
  float* RESTRICT u
) {
  ASSUME_ALIGNED(u, SIMD_BYTES);

  const float center_x{0.5f * static_cast<float>(nx - 1)};
  const float center_y{0.5f * static_cast<float>(ny - 1)};
  const float center_z{0.5f * static_cast<float>(nz - 1)};

  const float amplitude{1.0f};
  const float sigma{0.1f * static_cast<float>(nx)};
  const float two_sigma_sq{2.0f * sigma * sigma};
  const float inv_two_sig_sq{1.0f / two_sigma_sq};

  #pragma omp parallel for collapse(2)
  for (std::ptrdiff_t k = 0; k < static_cast<std::ptrdiff_t>(nz); ++k) {
    for (std::ptrdiff_t j = 0; j < static_cast<std::ptrdiff_t>(ny); ++j) {

      #pragma omp simd
      for (std::size_t i = 0; i < nx; ++i) {
        const float rx{static_cast<float>(i) - center_x};
        const float ry{static_cast<float>(j) - center_y};
        const float rz{static_cast<float>(k) - center_z};
        const float r_sq{rx*rx + ry*ry + rz*rz};

        const std::size_t point{i + p_nx * (j + p_ny * k)};
        u[point] = amplitude * std::exp(-r_sq * inv_two_sig_sq);
      }
    }
  }
}

void cpuInitializeCosineKernel(
  std::size_t nx, std::size_t ny, std::size_t nz,
  std::size_t p_nx, std::size_t p_ny,
  float* RESTRICT u
) {
  ASSUME_ALIGNED(u, SIMD_BYTES);

  #pragma omp parallel for collapse(2)
  for (std::ptrdiff_t k = 0; k < static_cast<std::ptrdiff_t>(nz); ++k) {
    for (std::ptrdiff_t j = 0; j < static_cast<std::ptrdiff_t>(ny); ++j) {

      const float cy{cosine_mode(static_cast<std::size_t>(j), ny)};
      const float cz{cosine_mode(static_cast<std::size_t>(k), nz)};

      #pragma omp simd
      for (std::size_t i = 0; i < nx; ++i) {
        const std::size_t point{i + p_nx * (j + p_ny * k)};
        u[point] = cosine_mode(i, nx) * cy * cz;
      }
    }
  }
}
#endif

} // namespace

void Simulation::initialize() {
#if defined(__CUDACC__)
  dim3 threads(8, 8, 8);

  if (ic_ == InitCondition::NeumannCosine) {
    dim3 blocks(
      (static_cast<unsigned>(grid_a_.nx()) + threads.x - 1) / threads.x,
      (static_cast<unsigned>(grid_a_.ny()) + threads.y - 1) / threads.y,
      (static_cast<unsigned>(grid_a_.nz()) + threads.z - 1) / threads.z
    );

    gpuInitializeCosineKernel<<<blocks, threads>>>(
      grid_a_.nx(), grid_a_.ny(), grid_a_.nz(),
      grid_a_.p_nx(), grid_a_.p_ny(),
      grid_a_.field()
    );
    CUDA_CHECK(cudaGetLastError());

    return;
  }

  dim3 blocks(
    (static_cast<unsigned>(grid_a_.nx()-1) + threads.x - 1 ) / threads.x,
    (static_cast<unsigned>(grid_a_.ny()-1) + threads.y - 1 ) / threads.y,
    (static_cast<unsigned>(grid_a_.nz()-1) + threads.z - 1 ) / threads.z
  );

  gpuInitializeGaussianKernel<<<blocks, threads>>>(
    grid_a_.nx(), grid_a_.ny(), grid_a_.nz(),
    grid_a_.p_nx(), grid_a_.p_ny(),
    grid_a_.field()
  );
  CUDA_CHECK(cudaGetLastError());
#else
  if (ic_ == InitCondition::NeumannCosine) {
    cpuInitializeCosineKernel(
      grid_a_.nx(), grid_a_.ny(), grid_a_.nz(),
      grid_a_.p_nx(), grid_a_.p_ny(),
      grid_a_.field()
    );
    return;
  }

  cpuInitializeGaussianKernel(
    grid_a_.nx(), grid_a_.ny(), grid_a_.nz(),
    grid_a_.p_nx(), grid_a_.p_ny(),
    grid_a_.field()
  );
#endif
}

void Simulation::run() {
  auto curr_grid{current_grid_};
  auto next_grid{(curr_grid == &grid_a_) ? &grid_b_ : &grid_a_};

  const bool enable_vtk{output_interval_ > 0};
  for (std::size_t step{}; step < total_steps_; ++step) {
    const bool output{
      enable_vtk           &&
      output_interval_ > 0 &&
      step % output_interval_ == 0
    };

    if (output) { vtk::write(*curr_grid, step); }

    integrator_->integrate(*curr_grid, *next_grid);
    std::swap(curr_grid, next_grid);
  }
  if (enable_vtk) { vtk::write(*curr_grid, total_steps_); }

  #if defined(__CUDACC__)
    CUDA_CHECK(cudaDeviceSynchronize());
  #endif

  current_grid_ = curr_grid;
}