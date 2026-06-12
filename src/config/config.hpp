#pragma once

#include <cstdint>

struct Config {
  std::size_t nx, ny, nz;
  float dx, dy, dz, dt;
  float alpha;

  std::size_t total_steps;
};