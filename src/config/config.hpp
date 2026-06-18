#pragma once

#include <cstdint>

struct Config {
  std::size_t total_steps{1000};
  std::size_t output_interval{0}; // 0 = disabled

  std::size_t nx{512};
  std::size_t ny{512};
  std::size_t nz{512};

  float dx{1.0f};
  float dy{1.0f};
  float dz{1.0f};

  float alpha{1.0f};
  float dt{
    0.85f / (2.0f * alpha * (1.0f/(dx*dx) + 1.0f/(dy*dy) + 1.0f/(dz*dz)))
  };
};