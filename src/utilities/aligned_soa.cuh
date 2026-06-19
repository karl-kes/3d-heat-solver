#pragma once

#include "macros.cuh"

#include <algorithm>
#include <cstddef>
#include <memory>
#include <new>
#include <cstdlib>

namespace {

inline void* aligned_alloc(std::size_t alignment, std::size_t size) {
#if defined(__CUDACC__)
  (void)alignment;

  void* ptr{};
  cudaMalloc(&ptr, size);

  return ptr;
#else
  return _aligned_malloc(size, alignment);
#endif
}

inline void aligned_free(void* ptr) {
#if defined(__CUDACC__)
  cudaFree(ptr);
#else
  _aligned_free(ptr);
#endif
}

struct AlignedDeleter {
  template <typename T>
  void operator()(T* ptr) const {
    aligned_free(ptr);
  }
};

} // namespace

template <typename T>
class AlignedSoA {
private:
  static constexpr std::size_t elements_per_align_{SIMD_BYTES / sizeof(T)};
  std::size_t num_elements_;
  std::size_t stride_length_;
  std::size_t num_arrays_;
  std::unique_ptr<T[], AlignedDeleter> data_;

public:
  AlignedSoA() : num_elements_{}, stride_length_{}, num_arrays_{}, data_{} {}
  AlignedSoA(AlignedSoA&&) noexcept = default;
  AlignedSoA& operator=(AlignedSoA&&) noexcept = default;

  AlignedSoA(std::size_t num_elements, std::size_t num_arrays)
  : num_elements_{num_elements}
  , stride_length_{round_up(num_elements)}
  , num_arrays_{num_arrays} {
    const std::size_t total_elements{num_arrays_ * stride_length_};
    const std::size_t total_bytes{total_elements * sizeof(T)};

    T* ptr{static_cast<T*>(aligned_alloc(SIMD_BYTES, total_bytes))};
    if (!ptr) { throw std::bad_alloc(); }

    #if defined(__CUDACC__)
      cudaMemset(ptr, 0, total_bytes);
    #else
      std::fill_n(ptr, total_elements, T{});
    #endif

    data_.reset(ptr);
  }

  [[nodiscard]]
  std::size_t stride() const {
    return stride_length_;
  }

  [[nodiscard]]
  T* operator[](std::size_t array_index) { 
    return data_.get() + array_index * stride();
  }

  [[nodiscard]]
  const T* operator[](std::size_t array_index) const {
    return data_.get() + array_index * stride();
  }

  [[nodiscard]]
  static constexpr std::size_t round_up(std::size_t unpadded) {
    return (unpadded + elements_per_align_ - 1) & 
          ~(elements_per_align_ - 1);
  }
};
