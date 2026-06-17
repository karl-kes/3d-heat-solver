#include "integrator.cuh"

Integrator::Integrator(const Config& config)
: dt_{config.dt}
, alpha_{config.alpha}
{ }

ExplicitEuler::ExplicitEuler(const Config& config)
: Integrator(config)
{ }

void ExplicitEuler::boundary_condition(Grid& grid) {
  const std::size_t nx{grid.nx()};
  const std::size_t ny{grid.ny()};
  const std::size_t nz{grid.nz()};

  float* RESTRICT u_new{grid.field()};
  ASSUME_ALIGNED(u_new, SIMD_BYTES);

  // X-faces:
  for (std::size_t k = 1; k < nz-1; ++k) {

    #pragma omp simd
    for (std::size_t j = 1; j < ny-1; ++j) {
      const std::size_t left_ghost{grid.idx(0,j,k)};
      const std::size_t left_inner{grid.idx(1,j,k)};

      const std::size_t right_ghost{grid.idx(nx-1,j,k)};
      const std::size_t right_inner{grid.idx(nx-2,j,k)};

      u_new[left_ghost] = u_new[left_inner];
      u_new[right_ghost] = u_new[right_inner];
    }
  }

  // Y-faces:
  for (std::size_t k = 1; k < nz-1; ++k) {

    #pragma omp simd
    for (std::size_t i = 0; i < nx; ++i) {
      const std::size_t front_ghost{grid.idx(i,0,k)};
      const std::size_t front_inner{grid.idx(i,1,k)};

      const std::size_t back_ghost{grid.idx(i,ny-1,k)};
      const std::size_t back_inner{grid.idx(i,ny-2,k)};

      u_new[front_ghost] = u_new[front_inner];
      u_new[back_ghost] = u_new[back_inner];
    }
  }

  // Z-faces:
  for (std::size_t j = 0; j < ny; ++j) {

    #pragma omp simd
    for (std::size_t i = 0; i < nx; ++i) {
      const std::size_t bottom_ghost{grid.idx(i,j,0)};
      const std::size_t bottom_inner{grid.idx(i,j,1)};

      const std::size_t top_ghost{grid.idx(i,j,nz-1)};
      const std::size_t top_inner{grid.idx(i,j,nz-2)};

      u_new[bottom_ghost] = u_new[bottom_inner];
      u_new[top_ghost] = u_new[top_inner];
    }
  }
}

__global__ void integrateGrid(float* data, int N) {

}

void ExplicitEuler::integrate(const Grid& old_grid, Grid& new_grid) {
  const std::size_t nx{old_grid.nx()};
  const std::size_t ny{old_grid.ny()};
  const std::size_t nz{old_grid.nz()};
  const float alpha_dt{alpha()*dt()};

  float* RESTRICT u_new{new_grid.field()};
  const float* RESTRICT u_old{old_grid.field()};

  ASSUME_ALIGNED(u_new, SIMD_BYTES);
  ASSUME_ALIGNED(u_old, SIMD_BYTES);

  #pragma omp parallel for collapse(2)
  for (std::ptrdiff_t k = 1; k < static_cast<std::ptrdiff_t>(nz-1); ++k) {
    for (std::ptrdiff_t j = 1; j < static_cast<std::ptrdiff_t>(ny-1); ++j) {

      #pragma omp simd
      for (std::size_t i = 1; i < nx-1; ++i) {
        const std::size_t point{old_grid.idx(i,j,k)};
        u_new[point] = u_old[point] + alpha_dt * old_grid.laplacian(i,j,k);
      }
    }
  }

  this->boundary_condition(new_grid);
}