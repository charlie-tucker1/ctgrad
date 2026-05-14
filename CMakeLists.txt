cmake_minimum_required(VERSION 3.27)
project(ctgrad LANGUAGES CXX CUDA)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CUDA_STANDARD 17)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)  # for clangd

# Target Blackwell (RTX 5070). Add older archs here if you want portability.
set(CMAKE_CUDA_ARCHITECTURES 120)

# Use ccache if available
find_program(CCACHE_PROGRAM ccache)
if(CCACHE_PROGRAM)
    set(CMAKE_CXX_COMPILER_LAUNCHER ${CCACHE_PROGRAM})
    set(CMAKE_CUDA_COMPILER_LAUNCHER ${CCACHE_PROGRAM})
endif()

# Find Python and nanobind
find_package(Python 3.12 COMPONENTS Interpreter Development.Module REQUIRED)
execute_process(
    COMMAND "${Python_EXECUTABLE}" -m nanobind --cmake_dir
    OUTPUT_STRIP_TRAILING_WHITESPACE OUTPUT_VARIABLE NB_DIR)
list(APPEND CMAKE_PREFIX_PATH "${NB_DIR}")
find_package(nanobind CONFIG REQUIRED)

# The extension module
nanobind_add_module(_ctgrad_ext
    src/cpp/bindings.cpp
    src/cuda/hello.cu
)

target_include_directories(_ctgrad_ext PRIVATE include)

install(TARGETS _ctgrad_ext LIBRARY DESTINATION ctgrad)
