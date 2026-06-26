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
  std::vector<float> field(grid.total_size());
  grid.copy_to_host(field.data());

  if (cfg.ic == InitCondition::NeumannCosine) {
    const float t{static_cast<float>(cfg.total_steps) * cfg.dt};
    const float lambda{neumann_decay_rate(cfg.alpha, cfg.dx, cfg.dy, cfg.dz, cfg.nx, cfg.ny, cfg.nz)};
    const float decay{std::exp(-lambda * t)};

    double sq_error_sum{};
    double sq_expected_sum{};
    for (std::size_t k{1}; k < cfg.nz - 1; ++k) {

      const float cz{cosine_mode(k, cfg.nz)};
      for (std::size_t j{1}; j < cfg.ny - 1; ++j) {

        const float cy{cosine_mode(j, cfg.ny)};
        for (std::size_t i{1}; i < cfg.nx - 1; ++i) {
          const float cx{cosine_mode(i, cfg.nx)};
          const float expected{cx * cy * cz * decay};
          const float actual{field[grid.idx(i, j, k)]};
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

  const float center_x{0.5f * static_cast<float>(cfg.nx - 1)};
  const float center_y{0.5f * static_cast<float>(cfg.ny - 1)};
  const float center_z{0.5f * static_cast<float>(cfg.nz - 1)};

  const float sigma0{0.1f * static_cast<float>(cfg.nx) * cfg.dx};
  const float t{static_cast<float>(cfg.total_steps) * cfg.dt};
  const float sigma_t_sq{sigma0 * sigma0 + 2.0f * cfg.alpha * t};
  const float amplitude_t{std::pow(sigma0 * sigma0 / sigma_t_sq, 1.5f)};

  double sq_error_sum{};
  double sq_expected_sum{};

  for (std::size_t k{}; k < cfg.nz; ++k) {
    for (std::size_t j{}; j < cfg.ny; ++j) {
      for (std::size_t i{}; i < cfg.nx; ++i) {
        const float rx{(static_cast<float>(i) - center_x) * cfg.dx};
        const float ry{(static_cast<float>(j) - center_y) * cfg.dy};
        const float rz{(static_cast<float>(k) - center_z) * cfg.dz};
        const float r_sq{rx * rx + ry * ry + rz * rz};
        const float expected{amplitude_t * std::exp(-r_sq / (2.0f * sigma_t_sq))};
        const float actual{field[grid.idx(i, j, k)]};

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
  const float rx_c{(static_cast<float>(cx) - center_x) * cfg.dx};
  const float ry_c{(static_cast<float>(cy) - center_y) * cfg.dy};
  const float rz_c{(static_cast<float>(cz) - center_z) * cfg.dz};
  const float r_sq_c{rx_c * rx_c + ry_c * ry_c + rz_c * rz_c};
  const float expected_center{amplitude_t * std::exp(-r_sq_c / (2.0f * sigma_t_sq))};
  const float actual_center{field[grid.idx(cx, cy, cz)]};
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
