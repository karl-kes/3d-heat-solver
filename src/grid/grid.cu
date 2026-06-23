#include "grid.cuh"

Grid::Grid(const Config& config)
: nx_{config.nx}, ny_{config.ny}, nz_{config.nz}
, dx_{config.dx}, dy_{config.dy}, dz_{config.dz}
, data_{total_size(), NUM_SUB_ARR}
{ }

Grid::~Grid() = default;

void Grid::copy_to_host(float* dst) const {
  const std::size_t total{total_size()};

#if defined(__CUDACC__)
  CUDA_CHECK(cudaMemcpy(dst, field(), total * sizeof(float), cudaMemcpyDeviceToHost));
#else
  std::copy_n(field(), total, dst);
#endif
}