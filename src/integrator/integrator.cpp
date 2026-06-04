#include "integrator.hpp"

Integrator::Integrator(const Config& config)
: dt_{config.dt}
, alpha_{config.alpha}
{ }

ExplicitEuler::ExplicitEuler(const Config& config)
: Integrator(config)
{ }

void ExplicitEuler::integrate(Grid& grid) {
  const auto old_grid{grid};

  const std::size_t nx{grid.padded_nx()};
  const std::size_t ny{grid.padded_ny()};
  const std::size_t nz{grid.padded_nz()};
  const double alpha_dt{alpha()*dt()};

  double* RESTRICT u_new{grid.field()};
  const double* RESTRICT u_old{old_grid.field()};

  for (std::size_t i{1}; i < nx-1; ++i) {
    for (std::size_t j{1}; j < ny-1; ++j) {
      for (std::size_t k{1}; k < nz-1; ++k) {
        
        const std::size_t point{grid.idx(i,j,k)};

        u_new[point] = u_old[point] + alpha_dt * old_grid.laplacian(i,j,k);
      }
    }
  }
}