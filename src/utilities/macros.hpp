#pragma once

#include <malloc.h>

#if defined(__GNUC__) || defined(__clang__)
  #define RESTRICT __restrict__
#elif defined(_MSC_VER)
  #define RESTRICT __restrict
#else
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
  return _aligned_malloc(size, alignment);
}

inline void aligned_free(void* ptr) {
  _aligned_free(ptr);
}

struct AlignedDeleter {
  template <typename T>
  void operator()(T* ptr) const {
    aligned_free(ptr);
  }
};
