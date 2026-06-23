#include "config/config.hpp"
#include "simulation/simulation.hpp"

#include <cmath>
#include <cstdio>
#include <vector>

namespace {

bool nearly_equal(float actual, float expected, float rel_tol) {
  const float diff{std::fabs(actual - expected)};
  const float scale{std::fabs(expected) > 1e-6f ? std::fabs(expected) : 1.0f};
  return diff <= rel_tol * scale;
}

std::vector<float> field_snapshot(const Grid& grid) {
  std::vector<float> field(grid.p_nx() * grid.p_ny() * grid.p_nz());
  grid.copy_to_host(field.data());
  return field;
}

} // namespace

int main() {
  Config cfg{};
  cfg.nx = cfg.ny = cfg.nz = 32;
  cfg.dx = cfg.dy = cfg.dz = 1.0f;
  cfg.alpha = 1.0f;
  cfg.output_interval = 0;
  cfg.total_steps = 0;
  cfg.dt = Config::stable_dt(cfg.alpha, cfg.dx, cfg.dy, cfg.dz);

  const std::size_t total_steps{40};

  Simulation sim0{cfg};
  const std::vector<float> field0{field_snapshot(sim0.grid())};
  const Grid& grid0{sim0.grid()};

  cfg.total_steps = total_steps;
  Simulation sim{cfg};
  sim.run();
  const std::vector<float> field{field_snapshot(sim.grid())};
  const Grid& grid{sim.grid()};

  // Check 1: value at the grid point nearest the center vs. the analytic
  // Gaussian-diffusion solution u(r, t) = amplitude * (sigma0/sigma_t)^3 * exp(-r^2 / (2*sigma_t^2))
  const float center_x{0.5f * static_cast<float>(cfg.nx - 1)};
  const float center_y{0.5f * static_cast<float>(cfg.ny - 1)};
  const float center_z{0.5f * static_cast<float>(cfg.nz - 1)};

  const std::size_t cx{cfg.nx / 2};
  const std::size_t cy{cfg.ny / 2};
  const std::size_t cz{cfg.nz / 2};

  const float rx{static_cast<float>(cx) - center_x};
  const float ry{static_cast<float>(cy) - center_y};
  const float rz{static_cast<float>(cz) - center_z};
  const float r_sq{rx * rx + ry * ry + rz * rz};

  const float sigma0{0.1f * static_cast<float>(cfg.nx)};
  const float t{static_cast<float>(total_steps) * cfg.dt};
  const float sigma_t_sq{sigma0 * sigma0 + 2.0f * cfg.alpha * t};
  const float amplitude_t{std::pow(sigma0 * sigma0 / sigma_t_sq, 1.5f)};
  const float expected{amplitude_t * std::exp(-r_sq / (2.0f * sigma_t_sq))};

  const float actual{field[grid.idx(cx, cy, cz)]};

  if (!nearly_equal(actual, expected, 0.05f)) {
    std::fprintf(stderr,
      "physical_correctness: center value mismatch (expected %.6f, got %.6f)\n",
      expected, actual);
    return 1;
  }

  // Check 2: conservation of energy (total sum) under the insulated boundary
  float sum0{};
  float sum{};
  for (std::size_t k{}; k < cfg.nz; ++k) {
    for (std::size_t j{}; j < cfg.ny; ++j) {
      for (std::size_t i{}; i < cfg.nx; ++i) {
        sum0 += field0[grid0.idx(i, j, k)];
        sum += field[grid.idx(i, j, k)];
      }
    }
  }

  if (!nearly_equal(sum, sum0, 0.02f)) {
    std::fprintf(stderr,
      "physical_correctness: sum not conserved (t=0 sum %.6f, final sum %.6f)\n",
      sum0, sum);
    return 1;
  }

  // Check 3: insulated boundary (du/dn = 0) ghost cells must exactly mirror
  // their adjacent interior cell, since the boundary kernel applies this as a
  // direct copy with no arithmetic.
  for (std::size_t k{1}; k < cfg.nz - 1; ++k) {
    for (std::size_t j{1}; j < cfg.ny - 1; ++j) {
      const float left_ghost{field[grid.idx(0, j, k)]};
      const float left_inner{field[grid.idx(1, j, k)]};
      const float right_ghost{field[grid.idx(cfg.nx - 1, j, k)]};
      const float right_inner{field[grid.idx(cfg.nx - 2, j, k)]};

      if (left_ghost != left_inner || right_ghost != right_inner) {
        std::fprintf(stderr,
          "physical_correctness: x-boundary not insulated at (j=%zu, k=%zu)\n", j, k);
        return 1;
      }
    }
  }

  for (std::size_t k{1}; k < cfg.nz - 1; ++k) {
    for (std::size_t i{}; i < cfg.nx; ++i) {
      const float front_ghost{field[grid.idx(i, 0, k)]};
      const float front_inner{field[grid.idx(i, 1, k)]};
      const float back_ghost{field[grid.idx(i, cfg.ny - 1, k)]};
      const float back_inner{field[grid.idx(i, cfg.ny - 2, k)]};

      if (front_ghost != front_inner || back_ghost != back_inner) {
        std::fprintf(stderr,
          "physical_correctness: y-boundary not insulated at (i=%zu, k=%zu)\n", i, k);
        return 1;
      }
    }
  }

  for (std::size_t j{}; j < cfg.ny; ++j) {
    for (std::size_t i{}; i < cfg.nx; ++i) {
      const float bottom_ghost{field[grid.idx(i, j, 0)]};
      const float bottom_inner{field[grid.idx(i, j, 1)]};
      const float top_ghost{field[grid.idx(i, j, cfg.nz - 1)]};
      const float top_inner{field[grid.idx(i, j, cfg.nz - 2)]};

      if (bottom_ghost != bottom_inner || top_ghost != top_inner) {
        std::fprintf(stderr,
          "physical_correctness: z-boundary not insulated at (i=%zu, j=%zu)\n", i, j);
        return 1;
      }
    }
  }

  return 0;
}
