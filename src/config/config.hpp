#pragma once

#include "../utilities/real.cuh"

#include <cstddef>
#include <cstdint>

enum class InitCondition { Gaussian, NeumannCosine };

struct Config {
  std::size_t total_steps{1000};
  std::size_t output_interval{0};
  InitCondition ic{InitCondition::Gaussian};

  std::size_t nx{64};
  std::size_t ny{64};
  std::size_t nz{64};

  Real dx{static_cast<Real>(1.0)};
  Real dy{static_cast<Real>(1.0)};
  Real dz{static_cast<Real>(1.0)};

  Real alpha{static_cast<Real>(1.0)};
  Real dt{stable_dt(alpha, dx, dy, dz)};

  static constexpr Real stable_dt(Real alpha, Real dx, Real dy, Real dz) {
    return static_cast<Real>(0.85) / (
      static_cast<Real>(2.0) * alpha *
      (static_cast<Real>(1.0)/(dx*dx) +
       static_cast<Real>(1.0)/(dy*dy) +
       static_cast<Real>(1.0)/(dz*dz))
    );
  }

  static Config parse(int argc, char** argv);
};