#pragma once

#include "../grid/grid.hpp"
#include "../integrator/integrator.hpp"

class Simulation {
private:
  Grid grid_;
  std::unique_ptr<Integrator> integrator_;

public:
  Simulation(const Config& config);
};