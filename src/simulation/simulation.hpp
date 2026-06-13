#pragma once

#include "../grid/grid.hpp"
#include "../integrator/integrator.hpp"

#include <utility>
#include <memory>

class Simulation {
private:
  std::size_t total_steps_;
  std::size_t output_interval_;

  Grid grid_a_;
  Grid grid_b_;
  std::unique_ptr<Integrator> integrator_;

public:
  Simulation(const Config& config);

  void run();
};