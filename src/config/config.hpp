#pragma once

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

  float dx{1.0f};
  float dy{1.0f};
  float dz{1.0f};

  float alpha{1.0f};
  float dt{stable_dt(alpha, dx, dy, dz)};

  static constexpr float stable_dt(float alpha, float dx, float dy, float dz) {
    return 0.85f / (2.0f * alpha * (1.0f/(dx*dx) + 1.0f/(dy*dy) + 1.0f/(dz*dz)));
  }

  static Config parse(int argc, char** argv);
};