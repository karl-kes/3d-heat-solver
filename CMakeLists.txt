cmake_minimum_required(VERSION 3.24)
project(heat_solver LANGUAGES CXX)

option(HEAT_SOLVER_ENABLE_CUDA "Enable CUDA acceleration if a CUDA compiler is available" ON)
set(HEAT_SOLVER_PRECISION "float" CACHE STRING "Floating-point precision: float or double")
set_property(CACHE HEAT_SOLVER_PRECISION PROPERTY STRINGS float double)
if(NOT HEAT_SOLVER_PRECISION STREQUAL "float" AND NOT HEAT_SOLVER_PRECISION STREQUAL "double")
  message(FATAL_ERROR "HEAT_SOLVER_PRECISION must be 'float' or 'double'")
endif()

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

set(HEAT_SOLVER_CORE_CUDA_SOURCES
  src/grid/grid.cu
  src/simulation/simulation.cu
  src/integrator/integrator.cu
)

set(HEAT_SOLVER_TEST_SOURCES
  tests/physics.cu
  tests/neumann.cu
  tests/config.cu
  tests/aligned_soa.cu
  tests/initialization.cu
  tests/convergence_order.cu
  tests/convergence.cu
)

set(HEAT_SOLVER_CUDA_EXTENSION_SOURCES
  ${HEAT_SOLVER_CORE_CUDA_SOURCES}
  ${HEAT_SOLVER_TEST_SOURCES}
)

add_library(heat_solver_core STATIC
  src/config/config.cpp
  ${HEAT_SOLVER_CORE_CUDA_SOURCES}
)

target_include_directories(heat_solver_core PUBLIC src)
if(HEAT_SOLVER_PRECISION STREQUAL "double")
  target_compile_definitions(heat_solver_core PUBLIC HEAT_SOLVER_PRECISION_DOUBLE=1)
endif()

if(NOT HEAT_SOLVER_CUDA)
  set_source_files_properties(
    ${HEAT_SOLVER_CUDA_EXTENSION_SOURCES}
    PROPERTIES LANGUAGE CXX
  )

  if(CMAKE_CXX_COMPILER_ID MATCHES "GNU|Clang")
    set_source_files_properties(
      ${HEAT_SOLVER_CUDA_EXTENSION_SOURCES}
      PROPERTIES COMPILE_OPTIONS "-x;c++"
    )
  endif()
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

function(add_heat_solver_test test_source)
  get_filename_component(test_name "${test_source}" NAME_WE)
  add_executable(test_${test_name} ${test_source})
  target_link_libraries(test_${test_name} PRIVATE heat_solver_core)
  add_test(NAME ${test_name} COMMAND test_${test_name} ${ARGN})
  if(HEAT_SOLVER_CUDA)
    set_tests_properties(${test_name} PROPERTIES SKIP_RETURN_CODE 77)
  endif()
endfunction()

add_heat_solver_test(tests/physics.cu)
add_heat_solver_test(tests/neumann.cu)
add_heat_solver_test(tests/config.cu)
add_heat_solver_test(tests/aligned_soa.cu)
add_heat_solver_test(tests/initialization.cu)
add_heat_solver_test(tests/convergence_order.cu)
add_heat_solver_test(tests/convergence.cu --nx 16 --ny 16 --nz 16 --steps 2 --output-interval 0)

add_test(NAME invalid_nx COMMAND heat_solver --nx 2 --steps 0 --output-interval 0)
set_tests_properties(invalid_nx PROPERTIES WILL_FAIL TRUE)

add_test(NAME invalid_alpha COMMAND heat_solver --alpha 0 --steps 0 --output-interval 0)
set_tests_properties(invalid_alpha PROPERTIES WILL_FAIL TRUE)

add_test(NAME invalid_dx COMMAND heat_solver --dx 0 --steps 0 --output-interval 0)
set_tests_properties(invalid_dx PROPERTIES WILL_FAIL TRUE)

add_executable(convergence_probe tests/convergence.cu)
target_link_libraries(convergence_probe PRIVATE heat_solver_core)
