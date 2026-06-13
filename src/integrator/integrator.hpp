#pragma once

#include "../grid/grid.hpp"
#include "../config/config.hpp"
#include "../utilities/macros.hpp"

#include <omp.h>

class Integrator {
private:
  float dt_;
  float alpha_;

public:
  explicit Integrator(const Config& config);
  virtual ~Integrator() = default;

  virtual void integrate(const Grid& old_grid, Grid& new_grid) = 0;

  float dt() const { return dt_; }
  float alpha() const { return alpha_; }

private:
  virtual void boundary_condition(Grid& grid) = 0;
};

class ExplicitEuler : public Integrator {
public:
  ExplicitEuler(const Config& config);

  void integrate(const Grid& old_grid, Grid& new_grid) override;

private:
  void boundary_condition(Grid& grid) override;
};