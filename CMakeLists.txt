cmake_minimum_required(VERSION 3.24)
project(heat_solver LANGUAGES CXX CUDA)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CUDA_STANDARD 17)
set(CMAKE_CUDA_STANDARD_REQUIRED ON)

if(NOT DEFINED CMAKE_CUDA_ARCHITECTURES)
  set(CMAKE_CUDA_ARCHITECTURES native)
endif()

add_executable(heat_solver
  src/main.cpp
  src/grid/grid.cpp
  src/simulation/simulation.cpp
  src/integrator/integrator.cu
)

target_include_directories(heat_solver PRIVATE src)

if(CMAKE_CXX_COMPILER_ID STREQUAL "MSVC")
  target_compile_options(heat_solver PRIVATE
    $<$<COMPILE_LANGUAGE:CXX>:/openmp:experimental>
    $<$<COMPILE_LANGUAGE:CUDA>:-Xcompiler=/openmp:experimental>
  )
else()
  find_package(OpenMP REQUIRED)
  target_link_libraries(heat_solver PRIVATE OpenMP::OpenMP_CXX)
  target_compile_options(heat_solver PRIVATE
    $<$<COMPILE_LANGUAGE:CUDA>:-Xcompiler=-fopenmp>
  )
endif()

set_target_properties(heat_solver PROPERTIES
  CUDA_SEPARABLE_COMPILATION ON
)
