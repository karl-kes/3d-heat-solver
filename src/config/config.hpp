#pragma once

#include <cstdint>

struct Config {
  std::size_t nx, ny, nz;
  double dx, dy, dz, dt;
  double alpha;
};