#pragma once

#include "../utilities/aligned_soa.cuh"
#include "../utilities/macros.cuh"
#include "../config/config.hpp"

#include <cstdint>

class Grid {
private:
  std::size_t nx_, ny_, nz_;
  Real dx_, dy_, dz_;

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

  [[nodiscard]] std::size_t p_nx() const { return AlignedSoA<Real>::round_up(nx_); }
  [[nodiscard]] std::size_t p_ny() const { return AlignedSoA<Real>::round_up(ny_); }
  [[nodiscard]] std::size_t p_nz() const { return AlignedSoA<Real>::round_up(nz_); }
  
  [[nodiscard]] std::size_t total_size() const { return p_nx()*p_ny()*p_nz(); }

  [[nodiscard]] Real dx() const { return dx_; }
  [[nodiscard]] Real dy() const { return dy_; }
  [[nodiscard]] Real dz() const { return dz_; }

  [[nodiscard]] Real inv_dx_sq() const { return static_cast<Real>(1.0)/(dx_*dx_); }
  [[nodiscard]] Real inv_dy_sq() const { return static_cast<Real>(1.0)/(dy_*dy_); }
  [[nodiscard]] Real inv_dz_sq() const { return static_cast<Real>(1.0)/(dz_*dz_); }

  [[nodiscard]]
  std::size_t idx(std::size_t x, std::size_t y, std::size_t z) const {
    return x + p_nx() * (y + p_ny() * z);
  }
};