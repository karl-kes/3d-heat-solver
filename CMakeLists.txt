cmake_minimum_required(VERSION 3.24)
project(heat_solver LANGUAGES CXX)

option(HEAT_SOLVER_ENABLE_CUDA "Enable CUDA acceleration if a CUDA compiler is available" ON)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(HEAT_SOLVER_CUDA OFF)
if(HEAT_SOLVER_ENABLE_CUDA)
  include(CheckLanguage)
  check_language(CUDA)
  if(CMAKE_CUDA_COMPILER)
    enable_language(CUDA)
    set(CMAKE_CUDA_STANDARD 20)
    set(CMAKE_CUDA_STANDARD_REQUIRED ON)
    if(NOT DEFINED CMAKE_CUDA_ARCHITECTURES)
      set(CMAKE_CUDA_ARCHITECTURES native)
    endif()
    set(HEAT_SOLVER_CUDA ON)
  endif()
endif()

add_library(heat_solver_core STATIC
  src/config/config.cpp
  src/grid/grid.cu
  src/simulation/simulation.cu
  src/integrator/integrator.cu
)

target_include_directories(heat_solver_core PUBLIC src)

if(NOT HEAT_SOLVER_CUDA)
  set_source_files_properties(
    src/grid/grid.cu
    src/simulation/simulation.cu
    src/integrator/integrator.cu
    PROPERTIES LANGUAGE CXX
  )
endif()

if(CMAKE_CXX_COMPILER_ID STREQUAL "MSVC")
  include(CheckCXXSourceRuns)

  set(CMAKE_REQUIRED_FLAGS "")
  check_cxx_source_runs("
    #include <intrin.h>
    int main() {
      int info[4];
      __cpuid(info, 0);
      if (info[0] < 7) { return 1; }
      __cpuidex(info, 7, 0);
      return (info[1] & (1 << 16)) ? 0 : 1; // AVX-512F (EBX bit 16)
    }
  " HEAT_SOLVER_HOST_HAS_AVX512)

  check_cxx_source_runs("
    #include <intrin.h>
    int main() {
      int info[4];
      __cpuid(info, 0);
      if (info[0] < 7) { return 1; }
      __cpuidex(info, 7, 0);
      return (info[1] & (1 << 5)) ? 0 : 1; // AVX2 (EBX bit 5)
    }
  " HEAT_SOLVER_HOST_HAS_AVX2)

  if(HEAT_SOLVER_HOST_HAS_AVX512)
    set(HEAT_SOLVER_ARCH_FLAG /arch:AVX512)
  elseif(HEAT_SOLVER_HOST_HAS_AVX2)
    set(HEAT_SOLVER_ARCH_FLAG /arch:AVX2)
  else()
    set(HEAT_SOLVER_ARCH_FLAG "")
  endif()

  set(HEAT_SOLVER_CUDA_XCOMPILE "-Xcompiler=/openmp:experimental,/W4,/WX,/wd4849,/wd4211")
  if(HEAT_SOLVER_ARCH_FLAG)
    string(APPEND HEAT_SOLVER_CUDA_XCOMPILE ",${HEAT_SOLVER_ARCH_FLAG}")
  endif()

  target_compile_options(heat_solver_core PRIVATE
    $<$<COMPILE_LANGUAGE:CXX>:/openmp:experimental /W4 /WX /wd4849 ${HEAT_SOLVER_ARCH_FLAG}>
    $<$<AND:$<COMPILE_LANGUAGE:CXX>,$<NOT:$<CONFIG:Debug>>>:/O2>
    $<$<AND:$<COMPILE_LANGUAGE:CUDA>,$<BOOL:${HEAT_SOLVER_CUDA}>>:${HEAT_SOLVER_CUDA_XCOMPILE}>
    $<$<AND:$<COMPILE_LANGUAGE:CUDA>,$<BOOL:${HEAT_SOLVER_CUDA}>,$<NOT:$<CONFIG:Debug>>>:-O3>
  )
else()
  find_package(OpenMP REQUIRED)
  target_link_libraries(heat_solver_core PUBLIC OpenMP::OpenMP_CXX)
  target_compile_options(heat_solver_core PRIVATE
    $<$<COMPILE_LANGUAGE:CXX>:-O3 -march=native -Wall -Wextra -Werror>
  )
  if(HEAT_SOLVER_CUDA)
    target_compile_options(heat_solver_core PRIVATE
      $<$<COMPILE_LANGUAGE:CUDA>:-Xcompiler=-fopenmp,-Wall,-Wextra,-Werror,-march=native>
      $<$<AND:$<COMPILE_LANGUAGE:CUDA>,$<NOT:$<CONFIG:Debug>>>:-O3>
    )
  endif()
endif()

if(HEAT_SOLVER_CUDA)
  set_target_properties(heat_solver_core PROPERTIES
    CUDA_SEPARABLE_COMPILATION ON
  )
endif()

add_executable(heat_solver src/main.cpp)
target_link_libraries(heat_solver PRIVATE heat_solver_core)

enable_testing()

add_executable(test_physics tests/physics.cpp)
target_link_libraries(test_physics PRIVATE heat_solver_core)
add_test(NAME physics COMMAND test_physics)

add_executable(test_config tests/config.cpp)
target_link_libraries(test_config PRIVATE heat_solver_core)
add_test(NAME config COMMAND test_config)

add_executable(test_aligned_soa tests/aligned_soa.cpp)
target_link_libraries(test_aligned_soa PRIVATE heat_solver_core)
add_test(NAME aligned_soa COMMAND test_aligned_soa)

# Measurement utility for docs/convergence.py, not a pass/fail test.
add_executable(convergence_probe tests/convergence.cpp)
target_link_libraries(convergence_probe PRIVATE heat_solver_core)
