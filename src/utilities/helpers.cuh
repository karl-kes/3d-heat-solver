#pragma once

#include "macros.cuh"

#include <cmath>
#include <cstddef>
#include <numbers>

// Per-axis factor of finite-domain Neumann cosine eigenmode at cell-centered index on an n-cell axis (n-2 interior).
CUDA_CALLABLE
inline float cosine_mode(std::size_t index, std::size_t n) {
  const float arg{
    std::numbers::pi_v<float> * (static_cast<float>(index) - 0.5f) / static_cast<float>(n - 2)
  };
#if defined(__CUDACC__)
  return cosf(arg);
#else
  return std::cos(arg);
#endif
}

inline float neumann_decay_rate(
  float alpha,
  float dx, float dy, float dz,
  std::size_t nx, std::size_t ny, std::size_t nz
) {
  constexpr float pi_sq{
    std::numbers::pi_v<float> * std::numbers::pi_v<float>
  };
  const float lx{static_cast<float>(nx - 2) * dx};
  const float ly{static_cast<float>(ny - 2) * dy};
  const float lz{static_cast<float>(nz - 2) * dz};
  
  return alpha * pi_sq * (1.0f / (lx * lx) + 1.0f / (ly * ly) + 1.0f / (lz * lz));
}
