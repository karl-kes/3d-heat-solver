#pragma once

#include <cstddef>

#if defined(__CUDACC__)
  #include <cuda_runtime.h>
  #define RESTRICT __restrict__
#elif defined(__GNUC__) || defined(__clang__)
  #include <malloc.h>
  #define RESTRICT __restrict__
#elif defined(_MSC_VER)
  #include <malloc.h>
  #define RESTRICT __restrict
#else
  #include <cstdlib>
  #define RESTRICT
#endif

#if defined(__CUDACC__)
  #define CUDA_CALLABLE __host__ __device__
#else
  #define CUDA_CALLABLE
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