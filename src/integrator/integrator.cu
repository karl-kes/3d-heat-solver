#include "integrator.cuh"

Integrator::Integrator(const Config& config)
: dt_{config.dt}
, alpha_{config.alpha}
{ }

ExplicitEuler::ExplicitEuler(const Config& config)
: Integrator(config)
{ }

#if defined(__CUDACC__)
__global__ void cudaBoundaryCondition(
  std::size_t nx, std::size_t ny, std::size_t nz,
  std::size_t p_nx, std::size_t p_ny, std::size_t p_nz,
  float* RESTRICT u_new
) {
  const std::size_t i{blockIdx.x * blockDim.x + threadIdx.x + 1};
  const std::size_t j{blockIdx.y * blockDim.y + threadIdx.y + 1};
  const std::size_t k{blockIdx.z * blockDim.z + threadIdx.z + 1};

  if (i >= nx-1 || j >= ny-1 || k >= nz-1) { return; }

  // X-faces:
  const std::size_t left_ghost{(0) + p_nx * ((j) + p_ny * (k))};
  const std::size_t left_inner{(1) + p_nx * ((j) + p_ny * (k))};
  const std::size_t right_ghost{(nx-1) + p_nx * ((j) + p_ny * (k))};
  const std::size_t right_inner{(nx-2) + p_nx * ((j) + p_ny * (k))};

  u_new[left_ghost] = u_new[left_inner];
  u_new[right_ghost] = u_new[right_inner];

  // Y-faces:
  const std::size_t front_ghost{(i) + p_nx * ((0) + p_ny * (k))};
  const std::size_t front_inner{(i) + p_nx * ((1) + p_ny * (k))};
  const std::size_t back_ghost{(i) + p_nx * ((ny-1) + p_ny * (k))};
  const std::size_t back_inner{(i) + p_nx * ((ny-2) + p_ny * (k))};

  u_new[front_ghost] = u_new[front_inner];
  u_new[back_ghost] = u_new[back_inner];

  // Z-faces:
  const std::size_t bottom_ghost{(i) + p_nx * ((j) + p_ny * (0))};
  const std::size_t bottom_inner{(i) + p_nx * ((j) + p_ny * (1))};
  const std::size_t top_ghost{(i) + p_nx * ((j) + p_ny * (nz-1))};
  const std::size_t top_inner{(i) + p_nx * ((j) + p_ny * (nz-2))};

  u_new[bottom_ghost] = u_new[bottom_inner];
  u_new[top_ghost] = u_new[top_inner];
}
#endif

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

#if defined(__CUDACC__)
__global__ void cudaIntegrateGrid(
  std::size_t nx, std::size_t ny, std::size_t nz,
  std::size_t p_nx, std::size_t p_ny, std::size_t p_nz,
  float inv_dx_sq, float inv_dy_sq, float inv_dz_sq,
  float alpha_dt,
  const float* RESTRICT u_old,
  float* RESTRICT u_new
) {
  const std::size_t i{blockIdx.x * blockDim.x + threadIdx.x + 1};
  const std::size_t j{blockIdx.y * blockDim.y + threadIdx.y + 1};
  const std::size_t k{blockIdx.z * blockDim.z + threadIdx.z + 1};

  if (i >= nx-1 || j >= ny-1 || k >= nz-1) { return; }

  // Laplacian points:
  const std::size_t x_low{(i-1) + p_nx * (j + p_ny * k)};
  const std::size_t x_high{(i+1) + p_nx * (j + p_ny * k)};

  const std::size_t y_low{i + p_nx * ((j-1) + p_ny * k)};
  const std::size_t y_high{i + p_nx * ((j+1) + p_ny * k)};

  const std::size_t z_low{i + p_nx * (j + p_ny * (k-1))};
  const std::size_t z_high{i + p_nx * (j + p_ny * (k+1))};

  // Center point:
  const std::size_t point{i + p_nx * (j + p_ny * k)};

  // Laplacian:
  const float laplacian{
      (u_old[x_low] - 2.0f * u_old[point] + u_old[x_high]) * inv_dx_sq +
      (u_old[y_low] - 2.0f * u_old[point] + u_old[y_high]) * inv_dy_sq +
      (u_old[z_low] - 2.0f * u_old[point] + u_old[z_high]) * inv_dz_sq
  };

  // Field update:
  u_new[point] = u_old[point] + alpha_dt * laplacian;
}
#endif

void ExplicitEuler::integrate(const Grid& old_grid, Grid& new_grid) {
  #if defined(__CUDACC__)
    dim3 threads(8, 8, 8);
    dim3 blocks(
      (static_cast<unsigned>(old_grid.nx()-2) + threads.x - 1) / threads.x,
      (static_cast<unsigned>(old_grid.ny()-2) + threads.y - 1) / threads.y,
      (static_cast<unsigned>(old_grid.nz()-2) + threads.z - 1) / threads.z
    );

    cudaIntegrateGrid<<<blocks, threads>>>(
      old_grid.nx(), old_grid.ny(), old_grid.nz(),
      old_grid.p_nx(), old_grid.p_ny(), old_grid.p_nz(),
      old_grid.inv_dx_sq(), old_grid.inv_dy_sq(), old_grid.inv_dz_sq(),
      alpha()*dt(),
      old_grid.field(),
      new_grid.field()
    );
    
    cudaBoundaryCondition<<<blocks, threads>>>(
      old_grid.nx(), old_grid.ny(), old_grid.nz(),
      old_grid.p_nx(), old_grid.p_ny(), old_grid.p_nz(),
      new_grid.field()
    );
  #else
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

    boundary_condition(new_grid);
  #endif
}