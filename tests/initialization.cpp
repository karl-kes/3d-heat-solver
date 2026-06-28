#include "config/config.hpp"
#include "simulation/simulation.hpp"
#include "utilities/helpers.cuh"

#include <algorithm>
#include <cmath>
#include <cstdio>
#include <vector>

namespace {

std::vector<Real> field_snapshot(const Grid& grid) {
  std::vector<Real> field(grid.total_size());
  grid.copy_to_host(field.data());
  return field;
}

bool nearly_equal(Real actual, Real expected) {
  const double diff{std::fabs(static_cast<double>(actual) - static_cast<double>(expected))};
  const double scale{std::max(1.0, std::fabs(static_cast<double>(expected)))};
  return diff <= 1e-6 * scale;
}

} // namespace

int main() {
  Config cfg{};
  cfg.nx = 17;
  cfg.ny = 19;
  cfg.nz = 21;
  cfg.total_steps = 0;
  cfg.output_interval = 0;

  {
    cfg.ic = InitCondition::Gaussian;
    Simulation sim{cfg};
    const Grid& grid{sim.grid()};
    const std::vector<Real> field{field_snapshot(grid)};

    const Real center_x{static_cast<Real>(0.5) * static_cast<Real>(cfg.nx - 1)};
    const Real center_y{static_cast<Real>(0.5) * static_cast<Real>(cfg.ny - 1)};
    const Real center_z{static_cast<Real>(0.5) * static_cast<Real>(cfg.nz - 1)};
    const Real sigma{static_cast<Real>(0.1) * static_cast<Real>(cfg.nx)};
    const Real inv_two_sigma_sq{static_cast<Real>(1.0) / (static_cast<Real>(2.0) * sigma * sigma)};

    for (std::size_t k{}; k < cfg.nz; ++k) {
      for (std::size_t j{}; j < cfg.ny; ++j) {
        for (std::size_t i{}; i < cfg.nx; ++i) {
          const Real rx{static_cast<Real>(i) - center_x};
          const Real ry{static_cast<Real>(j) - center_y};
          const Real rz{static_cast<Real>(k) - center_z};
          const Real expected{real_exp(-(rx * rx + ry * ry + rz * rz) * inv_two_sigma_sq)};
          const Real actual{field[grid.idx(i, j, k)]};

          if (!nearly_equal(actual, expected)) {
            std::fprintf(stderr, "gaussian initialization mismatch at (%zu,%zu,%zu)\n", i, j, k);
            return 1;
          }
        }
      }
    }
  }

  {
    cfg.ic = InitCondition::NeumannCosine;
    Simulation sim{cfg};
    const Grid& grid{sim.grid()};
    const std::vector<Real> field{field_snapshot(grid)};

    for (std::size_t k{}; k < cfg.nz; ++k) {
      for (std::size_t j{}; j < cfg.ny; ++j) {
        for (std::size_t i{}; i < cfg.nx; ++i) {
          const Real expected{cosine_mode(i, cfg.nx) * cosine_mode(j, cfg.ny) * cosine_mode(k, cfg.nz)};
          const Real actual{field[grid.idx(i, j, k)]};

          if (!nearly_equal(actual, expected)) {
            std::fprintf(stderr, "cosine initialization mismatch at (%zu,%zu,%zu)\n", i, j, k);
            return 1;
          }
        }
      }
    }
  }

  return 0;
}
