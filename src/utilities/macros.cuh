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

#if defined(__AVX512F__)
  constexpr std::size_t SIMD_BYTES{64};
#elif defined(__AVX2__) || defined(__AVX__)
  constexpr std::size_t SIMD_BYTES{32};
#elif defined(__SSE2__) || defined(_M_X64) || defined(_M_AMD64) || defined(__ARM_NEON) || defined(__aarch64__)
  constexpr std::size_t SIMD_BYTES{16};
#else
  constexpr std::size_t SIMD_BYTES{alignof(std::max_align_t)};
#endif