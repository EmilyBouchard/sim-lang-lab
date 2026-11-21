cmake_minimum_required(VERSION 3.28)
project(sim_lang_lab_cpp LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

find_program(CCACHE_PROGRAM ccache)
if(CCACHE_PROGRAM)
  set(CMAKE_CXX_COMPILER_LAUNCHER ${CCACHE_PROGRAM})
endif()

option(SIM_SANITIZE "Build with AddressSanitizer + UBSan" OFF)
if(SIM_SANITIZE)
  add_compile_options(-fsanitize=address,undefined -fno-omit-frame-pointer)
  add_link_options(-fsanitize=address,undefined)
endif()

add_compile_options(-Wall -Wextra -Wpedantic)

# SDL3 comes only from the pinned vcpkg install: `source scripts/env.sh` (build.sh does this).
if(NOT DEFINED ENV{SIM_VCPKG_PREFIX})
  message(FATAL_ERROR "SIM_VCPKG_PREFIX is not set. Run scripts/setup-deps.sh, then `source scripts/env.sh`.")
endif()
find_package(SDL3 3.4 REQUIRED CONFIG PATHS "$ENV{SIM_VCPKG_PREFIX}" NO_DEFAULT_PATH)

enable_testing()
add_subdirectory(apps/hello-window)
