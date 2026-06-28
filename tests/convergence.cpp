#include "config/config.hpp"
#include "simulation/simulation.hpp"
#include "utilities/helpers.cuh"

#include <cmath>
#include <cstdio>
#include <vector>

int main(int argc, char** argv) {
  const Config cfg{Config::parse(argc, argv)};

  Simulation sim{cfg};
  sim.run();

  const Grid& grid{sim.grid()};
  std::vector<Real> field(grid.total_size());
  grid.copy_to_host(field.data());

  if (cfg.ic == InitCondition::NeumannCosine) {
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
          const Real cx{cosine_mode(i, cfg.nx)};
          const Real expected{cx * cy * cz * decay};
          const Real actual{field[grid.idx(i, j, k)]};
          const double diff{static_cast<double>(actual) - static_cast<double>(expected)};

          sq_error_sum += diff * diff;
          sq_expected_sum += static_cast<double>(expected) * static_cast<double>(expected);
        }
      }
    }

    const double l2_rel_error{std::sqrt(sq_error_sum / sq_expected_sum)};
    std::printf(
      "%zu,%.6f,%zu,%.8f,%.6f,%.10f,%.10f\n",
      cfg.nx, cfg.dx, cfg.total_steps, cfg.dt, t, l2_rel_error, 0.0
    );
    return 0;
  }

  const Real center_x{static_cast<Real>(0.5) * static_cast<Real>(cfg.nx - 1)};
  const Real center_y{static_cast<Real>(0.5) * static_cast<Real>(cfg.ny - 1)};
  const Real center_z{static_cast<Real>(0.5) * static_cast<Real>(cfg.nz - 1)};

  const Real sigma0{static_cast<Real>(0.1) * static_cast<Real>(cfg.nx) * cfg.dx};
  const Real t{static_cast<Real>(cfg.total_steps) * cfg.dt};
  const Real sigma_t_sq{sigma0 * sigma0 + static_cast<Real>(2.0) * cfg.alpha * t};
  const Real amplitude_t{std::pow(sigma0 * sigma0 / sigma_t_sq, static_cast<Real>(1.5))};

  double sq_error_sum{};
  double sq_expected_sum{};

  for (std::size_t k{}; k < cfg.nz; ++k) {
    for (std::size_t j{}; j < cfg.ny; ++j) {
      for (std::size_t i{}; i < cfg.nx; ++i) {
        const Real rx{(static_cast<Real>(i) - center_x) * cfg.dx};
        const Real ry{(static_cast<Real>(j) - center_y) * cfg.dy};
        const Real rz{(static_cast<Real>(k) - center_z) * cfg.dz};
        const Real r_sq{rx * rx + ry * ry + rz * rz};
        const Real expected{amplitude_t * std::exp(-r_sq / (static_cast<Real>(2.0) * sigma_t_sq))};
        const Real actual{field[grid.idx(i, j, k)]};

        const double diff{static_cast<double>(actual) - static_cast<double>(expected)};
        sq_error_sum += diff * diff;
        sq_expected_sum += static_cast<double>(expected) * static_cast<double>(expected);
      }
    }
  }

  const double l2_rel_error{std::sqrt(sq_error_sum / sq_expected_sum)};

  const std::size_t cx{cfg.nx / 2};
  const std::size_t cy{cfg.ny / 2};
  const std::size_t cz{cfg.nz / 2};
  const Real rx_c{(static_cast<Real>(cx) - center_x) * cfg.dx};
  const Real ry_c{(static_cast<Real>(cy) - center_y) * cfg.dy};
  const Real rz_c{(static_cast<Real>(cz) - center_z) * cfg.dz};
  const Real r_sq_c{rx_c * rx_c + ry_c * ry_c + rz_c * rz_c};
  const Real expected_center{amplitude_t * std::exp(-r_sq_c / (static_cast<Real>(2.0) * sigma_t_sq))};
  const Real actual_center{field[grid.idx(cx, cy, cz)]};
  const double center_rel_error{
    std::fabs(static_cast<double>(actual_center) - static_cast<double>(expected_center))
    / static_cast<double>(expected_center)
  };

  std::printf(
    "%zu,%.6f,%zu,%.8f,%.6f,%.10f,%.10f\n",
    cfg.nx, cfg.dx, cfg.total_steps, cfg.dt, t, l2_rel_error, center_rel_error
  );

  return 0;
}
