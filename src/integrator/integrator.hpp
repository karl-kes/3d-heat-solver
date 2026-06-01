#pragma once

#include "../grid/grid.hpp"

class Integrator {
private:
  double dt_;

public:
  explicit Integrator(double dt) : dt_{dt} {}
  virtual ~Integrator() = default;

  virtual void integrate(Grid& grid) = 0;
  double dt() const { return dt_; }
};

class ExplicitEuler : public Integrator {
public:
  ExplicitEuler(double dt) : Integrator(dt) {}
  void integrate(Grid& grid) override;
};