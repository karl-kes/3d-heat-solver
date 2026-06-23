#pragma once

#include "../utilities/aligned_soa.cuh"
#include "../utilities/macros.cuh"
#include "../config/config.hpp"

#include <cstdint>

class Grid {
private:
  std::size_t nx_, ny_, nz_;
  float dx_, dy_, dz_;

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

  [[nodiscard]] std::size_t p_nx() const { return AlignedSoA<std::size_t>::round_up(nx_); }
  [[nodiscard]] std::size_t p_ny() const { return AlignedSoA<std::size_t>::round_up(ny_); }
  [[nodiscard]] std::size_t p_nz() const { return AlignedSoA<std::size_t>::round_up(nz_); }
  
  [[nodiscard]] std::size_t total_size() const { return p_nx()*p_ny()*p_nz(); }

  [[nodiscard]] float dx() const { return dx_; }
  [[nodiscard]] float dy() const { return dy_; }
  [[nodiscard]] float dz() const { return dz_; }

  [[nodiscard]] float inv_dx_sq() const { return 1.0f/(dx_*dx_); }
  [[nodiscard]] float inv_dy_sq() const { return 1.0f/(dy_*dy_); }
  [[nodiscard]] float inv_dz_sq() const { return 1.0f/(dz_*dz_); }

  [[nodiscard]]
  std::size_t idx(std::size_t x, std::size_t y, std::size_t z) const {
    return x + p_nx() * (y + p_ny() * z);
  }
};