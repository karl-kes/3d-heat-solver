#pragma once

#include "real.cuh"

#include <cmath>
#include <cstddef>
#include <numbers>

// Per-axis factor of finite-domain Neumann cosine eigenmode at cell-centered index on an n-cell axis (n-2 interior).
CUDA_CALLABLE
inline Real cosine_mode(std::size_t index, std::size_t n) {
  const Real arg{
    std::numbers::pi_v<Real> *
      (static_cast<Real>(index) - static_cast<Real>(0.5)) /
      static_cast<Real>(n - 2)
  };
  return real_cos(arg);
}

inline Real neumann_decay_rate(
  Real alpha,
  Real dx, Real dy, Real dz,
  std::size_t nx, std::size_t ny, std::size_t nz
) {
  constexpr Real pi_sq{
    std::numbers::pi_v<Real> * std::numbers::pi_v<Real>
  };
  const Real lx{static_cast<Real>(nx - 2) * dx};
  const Real ly{static_cast<Real>(ny - 2) * dy};
  const Real lz{static_cast<Real>(nz - 2) * dz};
  
  return alpha * pi_sq * (
    static_cast<Real>(1.0) / (lx * lx) +
    static_cast<Real>(1.0) / (ly * ly) +
    static_cast<Real>(1.0) / (lz * lz)
  );
}
