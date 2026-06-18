#pragma once

#if defined(__CUDACC__)
  #include <cuda_runtime.h>
  #define RESTRICT __restrict__
  constexpr bool CUDA{true};
#elif defined(__GNUC__) || defined(__clang__)
  #include <cstdlib>
  #define RESTRICT __restrict__
  constexpr bool CUDA{false};
#elif defined(_MSC_VER)
  #include <malloc.h>
  #define RESTRICT __restrict
  constexpr bool CUDA{false};
#else
  #include <cstdlib>
  constexpr bool CUDA{false};
  #define RESTRICT
#endif

#if defined(__GNUC__) || defined(__clang__)
  #define ASSUME_ALIGNED(ptr, align) \
    (ptr) = static_cast<decltype(ptr)>(__builtin_assume_aligned((ptr), (align)))
#elif defined(_MSC_VER)
  #define ASSUME_ALIGNED(ptr, align) \
    __assume((reinterpret_cast<uintptr_t>(ptr) % (align)) == 0)
#else
  #define ASSUME_ALIGNED(ptr, align) ((void)0)
#endif

constexpr std::size_t SIMD_BYTES{64};

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