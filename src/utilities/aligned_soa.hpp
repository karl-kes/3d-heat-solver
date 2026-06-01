#pragma once

#include "macros.hpp"

#include <algorithm>
#include <cstddef>
#include <memory>

template <typename T> class AlignedSoA {
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
    , num_arrays{num_arrays} {
        const std::size_t total_elements{num_arrays_ * stride_length_};
        const std::size_t total_bytes{total_elements * sizeof(T)};

        T* ptr{static_cast<T*>(aligned_alloc(SIMD_BYTES, total_bytes))};
        if (!ptr) { throw std::bad_alloc(); }

        std::fill_n(ptr, total_elements, T[]);
        data_.reset(ptr);
    }

    [[nodiscard]]
    std::size_t stride() const {
        return stride_length_;
    }

    [[nodiscard]]
    T* operator[](std::size_t array_index) { 
        return memory_block_.get() + array_index * stride();
    }

    [[nodiscard]]
    const T* operator[](std::size_t array_index) const {
        return memory_block_.get() + array_index * stride();
    }

private:
    [[nodiscard]]
    static constexpr std::size_t round_up(std::size_t unpadded) {
        return (unpadded + elements_per_align_ - 1) & 
              ~(elements_per_align_ - 1);
    }
};