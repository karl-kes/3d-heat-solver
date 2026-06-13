#pragma once

#include <cstdint>

struct Config {
  std::size_t nx = 100;
  std::size_t ny = 100;
  std::size_t nz = 100;

  float dx = 1.0f;
  float dy = 1.0f;
  float dz = 1.0f;
  
  float dt = 1.0f;
  float alpha = 1.0f;

  std::size_t total_steps = 1000;
};