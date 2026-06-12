#include "simulation.hpp"

Simulation::Simulation(const Config& config)
: grid_a_{config}
, grid_b_{config}
, integrator_{std::make_unique<ExplicitEuler>(config)}
, total_steps_{config.total_steps}
{ }

void Simulation::run() {
  auto curr_grid{&grid_a_};
  auto next_grid{&grid_b_};

  for (std::size_t step{}; step < total_steps_; ++step) {
    integrator_->integrate(*curr_grid, *next_grid);

    std::swap(curr_grid, next_grid);
  }
}