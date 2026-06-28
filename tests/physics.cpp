#include "config/config.hpp"
#include "simulation/simulation.hpp"

#include <cmath>
#include <cstdio>
#include <vector>

namespace {

bool nearly_equal(Real actual, Real expected, Real rel_tol) {
  const Real diff{std::fabs(actual - expected)};
  const Real scale{std::fabs(expected) > static_cast<Real>(1e-6) ? std::fabs(expected) : static_cast<Real>(1.0)};
  return diff <= rel_tol * scale;
}

std::vector<Real> field_snapshot(const Grid& grid) {
  std::vector<Real> field(grid.p_nx() * grid.p_ny() * grid.p_nz());
  grid.copy_to_host(field.data());
  return field;
}

} // namespace

int main() {
  Config cfg{};
  cfg.nx = cfg.ny = cfg.nz = 32;
  cfg.dx = cfg.dy = cfg.dz = static_cast<Real>(1.0);
  cfg.alpha = static_cast<Real>(1.0);
  cfg.output_interval = 0;
  cfg.total_steps = 0;
  cfg.dt = Config::stable_dt(cfg.alpha, cfg.dx, cfg.dy, cfg.dz);

  const std::size_t total_steps{40};

  Simulation sim0{cfg};
  const std::vector<Real> field0{field_snapshot(sim0.grid())};
  const Grid& grid0{sim0.grid()};

  cfg.total_steps = total_steps;
  Simulation sim{cfg};
  sim.run();
  const std::vector<Real> field{field_snapshot(sim.grid())};
  const Grid& grid{sim.grid()};

  // Check 1: center value vs. u(r,t) = amplitude * (sigma0/sigma_t)^3 * exp(-r^2/(2*sigma_t^2))
  const Real center_x{static_cast<Real>(0.5) * static_cast<Real>(cfg.nx - 1)};
  const Real center_y{static_cast<Real>(0.5) * static_cast<Real>(cfg.ny - 1)};
  const Real center_z{static_cast<Real>(0.5) * static_cast<Real>(cfg.nz - 1)};

  const std::size_t cx{cfg.nx / 2};
  const std::size_t cy{cfg.ny / 2};
  const std::size_t cz{cfg.nz / 2};

  const Real rx{static_cast<Real>(cx) - center_x};
  const Real ry{static_cast<Real>(cy) - center_y};
  const Real rz{static_cast<Real>(cz) - center_z};
  const Real r_sq{rx * rx + ry * ry + rz * rz};

  const Real sigma0{static_cast<Real>(0.1) * static_cast<Real>(cfg.nx)};
  const Real t{static_cast<Real>(total_steps) * cfg.dt};
  const Real sigma_t_sq{sigma0 * sigma0 + static_cast<Real>(2.0) * cfg.alpha * t};
  const Real amplitude_t{std::pow(sigma0 * sigma0 / sigma_t_sq, static_cast<Real>(1.5))};
  const Real expected{amplitude_t * std::exp(-r_sq / (static_cast<Real>(2.0) * sigma_t_sq))};

  const Real actual{field[grid.idx(cx, cy, cz)]};

  if (!nearly_equal(actual, expected, static_cast<Real>(0.05))) {
    std::fprintf(stderr,
      "physical_correctness: center value mismatch (expected %.6f, got %.6f)\n",
      expected, actual);
    return 1;
  }

  // Check 2: conservation of energy over interior cells (ghost layer excluded)
  Real sum0{};
  Real sum{};
  for (std::size_t k{1}; k < cfg.nz - 1; ++k) {
    for (std::size_t j{1}; j < cfg.ny - 1; ++j) {
      for (std::size_t i{1}; i < cfg.nx - 1; ++i) {
        sum0 += field0[grid0.idx(i, j, k)];
        sum += field[grid.idx(i, j, k)];
      }
    }
  }

  if (!nearly_equal(sum, sum0, static_cast<Real>(0.02))) {
    std::fprintf(stderr,
      "physical_correctness: sum not conserved (t=0 sum %.6f, final sum %.6f)\n",
      sum0, sum);
    return 1;
  }

  // Check 3: du/dn = 0 -- ghost cells must exactly mirror the adjacent interior cell.
  for (std::size_t k{1}; k < cfg.nz - 1; ++k) {
    for (std::size_t j{1}; j < cfg.ny - 1; ++j) {
      const Real left_ghost{field[grid.idx(0, j, k)]};
      const Real left_inner{field[grid.idx(1, j, k)]};
      const Real right_ghost{field[grid.idx(cfg.nx - 1, j, k)]};
      const Real right_inner{field[grid.idx(cfg.nx - 2, j, k)]};

      if (left_ghost != left_inner || right_ghost != right_inner) {
        std::fprintf(stderr,
          "physical_correctness: x-boundary not insulated at (j=%zu, k=%zu)\n", j, k);
        return 1;
      }
    }
  }

  for (std::size_t k{1}; k < cfg.nz - 1; ++k) {
    for (std::size_t i{}; i < cfg.nx; ++i) {
      const Real front_ghost{field[grid.idx(i, 0, k)]};
      const Real front_inner{field[grid.idx(i, 1, k)]};
      const Real back_ghost{field[grid.idx(i, cfg.ny - 1, k)]};
      const Real back_inner{field[grid.idx(i, cfg.ny - 2, k)]};

      if (front_ghost != front_inner || back_ghost != back_inner) {
        std::fprintf(stderr,
          "physical_correctness: y-boundary not insulated at (i=%zu, k=%zu)\n", i, k);
        return 1;
      }
    }
  }

  for (std::size_t j{}; j < cfg.ny; ++j) {
    for (std::size_t i{}; i < cfg.nx; ++i) {
      const Real bottom_ghost{field[grid.idx(i, j, 0)]};
      const Real bottom_inner{field[grid.idx(i, j, 1)]};
      const Real top_ghost{field[grid.idx(i, j, cfg.nz - 1)]};
      const Real top_inner{field[grid.idx(i, j, cfg.nz - 2)]};

      if (bottom_ghost != bottom_inner || top_ghost != top_inner) {
        std::fprintf(stderr,
          "physical_correctness: z-boundary not insulated at (i=%zu, j=%zu)\n", i, j);
        return 1;
      }
    }
  }

  return 0;
}
