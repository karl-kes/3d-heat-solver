cmake_minimum_required(VERSION 3.24)
project(heat_solver LANGUAGES CXX)

option(HEAT_SOLVER_ENABLE_CUDA "Enable CUDA acceleration if a CUDA compiler is available" ON)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(HEAT_SOLVER_CUDA OFF)
if(HEAT_SOLVER_ENABLE_CUDA)
  include(CheckLanguage)
  check_language(CUDA)
  if(CMAKE_CUDA_COMPILER)
    enable_language(CUDA)
    set(CMAKE_CUDA_STANDARD 17)
    set(CMAKE_CUDA_STANDARD_REQUIRED ON)
    if(NOT DEFINED CMAKE_CUDA_ARCHITECTURES)
      set(CMAKE_CUDA_ARCHITECTURES native)
    endif()
    set(HEAT_SOLVER_CUDA ON)
  endif()
endif()

add_executable(heat_solver
  src/main.cpp
  src/grid/grid.cu
  src/simulation/simulation.cpp
  src/integrator/integrator.cu
)

target_include_directories(heat_solver PRIVATE src)

if(NOT HEAT_SOLVER_CUDA)
  set_source_files_properties(
    src/grid/grid.cu
    src/integrator/integrator.cu
    PROPERTIES LANGUAGE CXX
  )
endif()

if(CMAKE_CXX_COMPILER_ID STREQUAL "MSVC")
  target_compile_options(heat_solver PRIVATE
    $<$<COMPILE_LANGUAGE:CXX>:/openmp:experimental>
    $<$<AND:$<COMPILE_LANGUAGE:CUDA>,$<BOOL:${HEAT_SOLVER_CUDA}>>:-Xcompiler=/openmp:experimental>
  )
else()
  find_package(OpenMP REQUIRED)
  target_link_libraries(heat_solver PRIVATE OpenMP::OpenMP_CXX)
  if(HEAT_SOLVER_CUDA)
    target_compile_options(heat_solver PRIVATE
      $<$<COMPILE_LANGUAGE:CUDA>:-Xcompiler=-fopenmp>
    )
  endif()
endif()

if(HEAT_SOLVER_CUDA)
  set_target_properties(heat_solver PROPERTIES
    CUDA_SEPARABLE_COMPILATION ON
  )
endif()
