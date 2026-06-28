#pragma once

#include "../grid/grid.cuh"
#include "../config/config.hpp"
#include "../utilities/macros.cuh"

class Integrator {
private:
  Real dt_;
  Real alpha_;

public:
  explicit Integrator(const Config& config);
  virtual ~Integrator() = default;

  virtual void integrate(const Grid& old_grid, Grid& new_grid) = 0;

  Real dt() const { return dt_; }
  Real alpha() const { return alpha_; }
};

class ExplicitEuler : public Integrator {
public:
  ExplicitEuler(const Config& config);
  void integrate(const Grid& old_grid, Grid& new_grid) override;
};