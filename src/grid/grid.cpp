#include "grid.hpp"

Grid::Grid(
  std::size_t x, std::size_t y, std::size_t z,
  double dx, double dy, double dz)
: nx_{x}, ny_{y}, nz_{z}
, inv_dx_sq{1.0/(dx*dx)}
, inv_dy_sq{1.0/(dy*dy)}
, inv_dz_sq{1.0/(dz*dz)} {

}