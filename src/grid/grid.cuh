#pragma once

#include "../utilities/aligned_soa.cuh"
#include "../utilities/macros.cuh"
#include "../config/config.hpp"

#include <cstdint>

class Grid {
private:
  std::size_t nx_, ny_, nz_;
  std::size_t p_nx_, p_ny_, p_nz_;
  Real dx_, dy_, dz_;
  Real inv_dx_sq_, inv_dy_sq_, inv_dz_sq_;

  AlignedSoA<Real> data_;

  enum : std::size_t {
    U, NUM_SUB_ARR
  };

public:
  Grid(const Config& config);
  ~Grid();

  [[nodiscard]] Real* field() { return data_[U]; }
  [[nodiscard]] const Real* field() const { return data_[U]; }

  void copy_to_host(Real* dst) const;

  [[nodiscard]] std::size_t nx() const { return nx_; }
  [[nodiscard]] std::size_t ny() const { return ny_; }
  [[nodiscard]] std::size_t nz() const { return nz_; }

  [[nodiscard]] std::size_t p_nx() const { return p_nx_; }
  [[nodiscard]] std::size_t p_ny() const { return p_ny_; }
  [[nodiscard]] std::size_t p_nz() const { return p_nz_; }
  
  [[nodiscard]] std::size_t total_size() const { return p_nx_*p_ny_*p_nz_; }

  [[nodiscard]] Real dx() const { return dx_; }
  [[nodiscard]] Real dy() const { return dy_; }
  [[nodiscard]] Real dz() const { return dz_; }

  [[nodiscard]] Real inv_dx_sq() const { return inv_dx_sq_; }
  [[nodiscard]] Real inv_dy_sq() const { return inv_dy_sq_; }
  [[nodiscard]] Real inv_dz_sq() const { return inv_dz_sq_; }

  [[nodiscard]]
  std::size_t idx(std::size_t x, std::size_t y, std::size_t z) const {
    return x + p_nx_ * (y + p_ny_ * z);
  }
};