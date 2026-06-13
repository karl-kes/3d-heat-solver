#pragma once

#include "../utilities/aligned_soa.hpp"
#include "../config/config.hpp"

#include <cstdint>

class Grid {
private:
  std::size_t nx_, ny_, nz_;
  std::size_t padded_nx_, padded_ny_, padded_nz_;

  float dx_, dy_, dz_;
  float inv_dx_sq_, inv_dy_sq_, inv_dz_sq_;

  AlignedSoA<float> data_;

  enum : std::size_t {
    U, NUM_SUB_ARR
  };

public:
  Grid(const Config& config);

  [[nodiscard]]
  float laplacian(std::size_t x, std::size_t y, std::size_t z) const {
    const std::size_t center{idx(x,y,z)};

    const std::size_t x_low{idx(x-1,y,z)};
    const std::size_t x_high{idx(x+1,y,z)};

    const std::size_t y_low{idx(x,y-1,z)};
    const std::size_t y_high{idx(x,y+1,z)};
    
    const std::size_t z_low{idx(x,y,z-1)};
    const std::size_t z_high{idx(x,y,z+1)};

    const float* RESTRICT u{field()};
    const float laplacian{
      (u[x_low] - 2.0f * u[center] + u[x_high]) * inv_dx_sq_ +
      (u[y_low] - 2.0f * u[center] + u[y_high]) * inv_dy_sq_ +
      (u[z_low] - 2.0f * u[center] + u[z_high]) * inv_dz_sq_
    };

    return laplacian;
  }

  [[nodiscard]] float* field() { return data_[U]; }
  [[nodiscard]] const float* field() const { return data_[U]; }

  [[nodiscard]] std::size_t nx() const { return nx_; }
  [[nodiscard]] std::size_t ny() const { return ny_; }
  [[nodiscard]] std::size_t nz() const { return nz_; }

  [[nodiscard]]
  std::size_t idx(std::size_t x, std::size_t y, std::size_t z) const {
    return x + padded_nx_ * (y + padded_ny_ * z);
  }
};