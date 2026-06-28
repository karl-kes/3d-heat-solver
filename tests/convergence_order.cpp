#include "config/config.hpp"
#include "simulation/simulation.hpp"
#include "utilities/helpers.cuh"

#include <array>
#include <cmath>
#include <cstdio>
#include <vector>

namespace {

double cosine_l2_error(std::size_t n) {
  Config cfg{};
  cfg.nx = cfg.ny = cfg.nz = n;
  cfg.dx = cfg.dy = cfg.dz = static_cast<Real>(1.0) / static_cast<Real>(n - 2);
  cfg.alpha = static_cast<Real>(1.0);
  cfg.ic = InitCondition::NeumannCosine;
  cfg.output_interval = 0;

  const Real target_t{static_cast<Real>(0.01)};
  cfg.dt = Config::stable_dt(cfg.alpha, cfg.dx, cfg.dy, cfg.dz);
  cfg.total_steps = static_cast<std::size_t>(std::ceil(static_cast<double>(target_t / cfg.dt)));

  Simulation sim{cfg};
  sim.run();

  const Grid& grid{sim.grid()};
  std::vector<Real> field(grid.total_size());
  grid.copy_to_host(field.data());

  const Real t{static_cast<Real>(cfg.total_steps) * cfg.dt};
  const Real lambda{neumann_decay_rate(cfg.alpha, cfg.dx, cfg.dy, cfg.dz, cfg.nx, cfg.ny, cfg.nz)};
  const Real decay{std::exp(-lambda * t)};

  double sq_error_sum{};
  double sq_expected_sum{};
  for (std::size_t k{1}; k < cfg.nz - 1; ++k) {
    const Real cz{cosine_mode(k, cfg.nz)};
    for (std::size_t j{1}; j < cfg.ny - 1; ++j) {
      const Real cy{cosine_mode(j, cfg.ny)};
      for (std::size_t i{1}; i < cfg.nx - 1; ++i) {
        const Real expected{cosine_mode(i, cfg.nx) * cy * cz * decay};
        const Real actual{field[grid.idx(i, j, k)]};
        const double diff{static_cast<double>(actual) - static_cast<double>(expected)};
        sq_error_sum += diff * diff;
        sq_expected_sum += static_cast<double>(expected) * static_cast<double>(expected);
      }
    }
  }

  return std::sqrt(sq_error_sum / sq_expected_sum);
}

} // namespace

int main() {
  constexpr std::array<std::size_t, 3> sizes{16, 32, 64};
  std::array<double, sizes.size()> errors{};

  for (std::size_t idx{}; idx < sizes.size(); ++idx) {
    errors[idx] = cosine_l2_error(sizes[idx]);
    if (!(errors[idx] > 0.0 && std::isfinite(errors[idx]))) {
      std::fprintf(stderr, "invalid convergence error for n=%zu\n", sizes[idx]);
      return 1;
    }
  }

  const double order_16_32{std::log(errors[0] / errors[1]) / std::log(2.0)};
  const double order_32_64{std::log(errors[1] / errors[2]) / std::log(2.0)};
  const double observed_order{0.5 * (order_16_32 + order_32_64)};

  if (observed_order < 1.8 || observed_order > 2.3) {
    std::fprintf(stderr,
      "unexpected convergence order %.3f (errors: %.6e %.6e %.6e)\n",
      observed_order, errors[0], errors[1], errors[2]);
    return 1;
  }

  return 0;
}
