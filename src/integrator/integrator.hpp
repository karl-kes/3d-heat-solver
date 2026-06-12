#pragma once

#include "../grid/grid.hpp"
#include "../config/config.hpp"

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
};

class ExplicitEuler : public Integrator {
public:
  ExplicitEuler(const Config& config);

  void integrate(const Grid& old_grid, Grid& new_grid) override;
};