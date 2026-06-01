#include "simulation.hpp"

Simulation::Simulation(const Config& config)
: grid_{config}
, integrator_{std::make_unique<ExplicitEuler>(config.dt)}
{ }