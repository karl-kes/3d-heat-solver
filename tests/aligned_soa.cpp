#include "utilities/aligned_soa.cuh"

int main() {
  constexpr std::size_t elems_per_align{SIMD_BYTES / sizeof(float)};

  // round_up pads up to the next multiple of the SIMD alignment
  if (AlignedSoA<float>::round_up(0) != 0) { return 1; }
  if (AlignedSoA<float>::round_up(elems_per_align) != elems_per_align) { return 1; }
  if (AlignedSoA<float>::round_up(1) != elems_per_align) { return 1; }
  if (AlignedSoA<float>::round_up(elems_per_align + 1) != 2 * elems_per_align) { return 1; }

  // allocated storage is correctly strided and zero-initialized
  AlignedSoA<float> soa{5, 2};
  if (soa.stride() != AlignedSoA<float>::round_up(5)) { return 1; }

  for (std::size_t arr{}; arr < 2; ++arr) {
    for (std::size_t i{}; i < soa.stride(); ++i) {
      if (soa[arr][i] != 0.0f) { return 1; }
    }
  }

  return 0;
}
