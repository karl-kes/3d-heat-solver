#pragma once

#include "../grid/grid.hpp"
#include "../config/config.hpp"

class Integrator {
private:
  double dt_;
  double alpha_;

public:
  explicit Integrator(const Config& config)
  : dt_{config.dt}
  , alpha_{config.alpha}
  { }
  virtual ~Integrator() = default;

  virtual void integrate(Grid& grid) = 0;

  double dt() const { return dt_; }
  double alpha() const { return alpha_; }
};

class ExplicitEuler : public Integrator {
public:
  ExplicitEuler(const Config& config) : Integrator(config) {}
  void integrate(Grid& grid) override;
};