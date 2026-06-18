#include "simulation.hpp"
#include "../io/vtk_writer.hpp"

#include <cmath>

Simulation::Simulation(const Config& config)
: grid_a_{config}
, grid_b_{config}
, integrator_{std::make_unique<ExplicitEuler>(config)}
, total_steps_{config.total_steps}
, output_interval_{config.output_interval} {
  // initialize();
}

void Simulation::initialize() {
  const std::size_t nx{grid_a_.nx()};
  const std::size_t ny{grid_a_.ny()};
  const std::size_t nz{grid_a_.nz()};

  float* RESTRICT u{grid_a_.field()};
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

        const std::size_t point{grid_a_.idx(i,j,k)};
        u[point] = amplitude * std::exp(-r_sq * inv_two_sig_sq);
      }
    }
  }
}

void Simulation::run() {
  auto curr_grid{&grid_a_};
  auto next_grid{&grid_b_};

  const bool enable_vtk{output_interval_ > 0};
  for (std::size_t step{}; step < total_steps_; ++step) {
    const bool output{
      enable_vtk &&
      output_interval_ > 0 &&
      step % output_interval_ == 0
    };

    if (output) { vtk::write(*curr_grid, step); }

    integrator_->integrate(*curr_grid, *next_grid);
    std::swap(curr_grid, next_grid);
  }

  if(enable_vtk) { vtk::write(*curr_grid, total_steps_); }
}