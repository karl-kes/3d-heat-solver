#pragma once

#include "../utilities/aligned_soa.cuh"
#include "../utilities/macros.cuh"
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
  ~Grid();

  [[nodiscard]] float* field() { return data_[U]; }
  [[nodiscard]] const float* field() const { return data_[U]; }

  void copy_to_host(float* dst) const;

  [[nodiscard]] std::size_t nx() const { return nx_; }
  [[nodiscard]] std::size_t ny() const { return ny_; }
  [[nodiscard]] std::size_t nz() const { return nz_; }

  [[nodiscard]] std::size_t p_nx() const { return padded_nx_; }
  [[nodiscard]] std::size_t p_ny() const { return padded_ny_; }
  [[nodiscard]] std::size_t p_nz() const { return padded_nz_; }

  [[nodiscard]] float dx() const { return dx_; }
  [[nodiscard]] float dy() const { return dy_; }
  [[nodiscard]] float dz() const { return dz_; }

  [[nodiscard]] float inv_dx_sq() const { return inv_dx_sq_; }
  [[nodiscard]] float inv_dy_sq() const { return inv_dy_sq_; }
  [[nodiscard]] float inv_dz_sq() const { return inv_dz_sq_; }

  [[nodiscard]]
  std::size_t idx(std::size_t x, std::size_t y, std::size_t z) const {
    return x + padded_nx_ * (y + padded_ny_ * z);
  }
};