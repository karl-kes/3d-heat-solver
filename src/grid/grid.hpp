#pragma once

#include "../utilities/aligned_soa.hpp"

#include <cstdint>

class Grid {
private:
  std::size_t nx_, ny_, nz_;
  double inv_dx_sq, inv_dy_sq, inv_dz_sq;

  AlignedSoA<double> cell_;

public:
  Grid(
    std::size_t x, std::size_t y, std::size_t z,
    double dx, double dy, double dz
  );

private:
  [[nodiscard]]
  std::size_t idx(std::size_t x, std::size_t y, std::size_t z) {
    return x + nx_ * (y + ny_ * z);
  }
};