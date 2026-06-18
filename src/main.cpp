#include "simulation/simulation.hpp"
#include "utilities/timer.hpp"

#include <iostream>

int main() {
  Config cfg{};
  Simulation sim{cfg};

  Timer timer{};
  sim.run();
  std::cout << timer.elapsed_ms() << "ms\n";
  std::cout.flush();

  return 0;
}