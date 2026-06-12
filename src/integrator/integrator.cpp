#include "integrator.hpp"

Integrator::Integrator(const Config& config)
: dt_{config.dt}
, alpha_{config.alpha}
{ }

ExplicitEuler::ExplicitEuler(const Config& config)
: Integrator(config)
{ }

void ExplicitEuler::integrate(const Grid& old_grid, Grid& new_grid) {
  const std::size_t nx{old_grid.nx()};
  const std::size_t ny{old_grid.ny()};
  const std::size_t nz{old_grid.nz()};
  const float alpha_dt{alpha()*dt()};

  float* RESTRICT u_new{new_grid.field()};
  const float* RESTRICT u_old{old_grid.field()};

  for (std::size_t k{1}; k < nz-1; ++k) {
    for (std::size_t j{1}; j < ny-1; ++j) {
      for (std::size_t i{1}; i < nx-1; ++i) {
        
        const std::size_t point{old_grid.idx(i,j,k)};

        u_new[point] = u_old[point] + alpha_dt * old_grid.laplacian(i,j,k);
      }
    }
  }
}