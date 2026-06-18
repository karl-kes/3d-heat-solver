#include "grid.cuh"

Grid::Grid(const Config& config)
: nx_{config.nx}, ny_{config.ny}, nz_{config.nz}
, padded_nx_{AlignedSoA<std::size_t>::round_up(nx_)}
, padded_ny_{AlignedSoA<std::size_t>::round_up(ny_)}
, padded_nz_{AlignedSoA<std::size_t>::round_up(nz_)}
, dx_{config.dx}, dy_{config.dy}, dz_{config.dz}
, inv_dx_sq_{1.0f/(dx_*dx_)}
, inv_dy_sq_{1.0f/(dy_*dy_)}
, inv_dz_sq_{1.0f/(dz_*dz_)}
, data_{padded_nx_*padded_ny_*padded_nz_, NUM_SUB_ARR}
{ }

Grid::~Grid() = default;