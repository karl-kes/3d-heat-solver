#pragma once

#include "../utilities/aligned_soa.hpp"

#include <cstdint>

class Grid {
private:
    std::size_t nx_, ny_, nz_;

    AlignedSoA<double> cell_;

public:
    // Uniform constructor:
    Grid(std::size_t n = 10);

    // Non-uniform constructor:
    Grid(std::size_t x, std::size_t y, std::size_t z);

private:
    [[nodiscard]]
    std::size_t idx(std::size_t x, std::size_t y, std::size_t z) {
        return x + nx_ * (y + ny_ * z);
    }
};