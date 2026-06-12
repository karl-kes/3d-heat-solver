#pragma once

#include "../grid/grid.hpp"
#include "../integrator/integrator.hpp"

#include <utility>
#include <memory>

class Simulation {
private:
  Grid grid_a_;
  Grid grid_b_;
  std::unique_ptr<Integrator> integrator_;

  std::size_t total_steps_;

public:
  Simulation(const Config& config);

  void run();
};