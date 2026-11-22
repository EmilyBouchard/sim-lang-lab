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

option(SIM_SANITIZE "Build with AddressSanitizer (+ UBSan where supported)" OFF)
if(MSVC)
  # MSVC has ASan but no UBSan. ASan is incompatible with the default /RTC1 runtime checks.
  if(SIM_SANITIZE)
    add_compile_options(/fsanitize=address)
    # Drop /RTC1 two ways: CMake >= 3.31 with policy CMP0184 NEW models it as a variable, older
    # behaviour (or policy OLD) keeps it in the flags string.
    set(CMAKE_MSVC_RUNTIME_CHECKS "")
    string(REGEX REPLACE "/RTC[1csu]+" "" CMAKE_CXX_FLAGS_DEBUG "${CMAKE_CXX_FLAGS_DEBUG}")
  endif()
  add_compile_options(/W4 /permissive- /utf-8 /Zc:__cplusplus)
else()
  if(SIM_SANITIZE)
    # -fno-sanitize-recover makes undefined behaviour abort, so ctest actually fails on it.
    add_compile_options(-fsanitize=address,undefined -fno-sanitize-recover=undefined -fno-omit-frame-pointer)
    add_link_options(-fsanitize=address,undefined)
  endif()
  add_compile_options(-Wall -Wextra -Wpedantic)
endif()

# SDL3 comes only from the pinned vcpkg install: `source scripts/env.sh` (build.sh does this).
if(NOT DEFINED ENV{SIM_VCPKG_PREFIX})
  message(FATAL_ERROR "SIM_VCPKG_PREFIX is not set. Run scripts/setup-deps.sh, then `source scripts/env.sh` (Windows: scripts/setup-deps.ps1, then `. ./scripts/env.ps1`).")
endif()
find_package(SDL3 3.4 REQUIRED CONFIG PATHS "$ENV{SIM_VCPKG_PREFIX}" NO_DEFAULT_PATH)

# CLI11 is vendored as its single-header release (see third_party/CLI11/README.md). SYSTEM keeps
# our warning flags from firing inside it.
add_library(CLI11 INTERFACE)
add_library(CLI11::CLI11 ALIAS CLI11)
target_include_directories(CLI11 SYSTEM INTERFACE "${CMAKE_CURRENT_SOURCE_DIR}/third_party/CLI11")

# Copy the DLLs an executable needs next to it, so it runs from any shell or by double-click.
# Windows only: on Linux the binary records an RPATH to the vcpkg install instead.
function(sim_copy_runtime_dlls target)
  if(NOT WIN32)
    return()
  endif()
  add_custom_command(TARGET ${target} POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_if_different $<TARGET_RUNTIME_DLLS:${target}> $<TARGET_FILE_DIR:${target}>
    COMMAND_EXPAND_LISTS)
  # MSVC AddressSanitizer needs its runtime DLLs. They sit next to cl.exe, which is on PATH only
  # inside a Visual Studio environment.
  if(MSVC AND SIM_SANITIZE)
    get_filename_component(_compiler_dir "${CMAKE_CXX_COMPILER}" DIRECTORY)
    foreach(_dll clang_rt.asan_dynamic-x86_64.dll clang_rt.asan_dbg_dynamic-x86_64.dll)
      if(EXISTS "${_compiler_dir}/${_dll}")
        add_custom_command(TARGET ${target} POST_BUILD
          COMMAND ${CMAKE_COMMAND} -E copy_if_different "${_compiler_dir}/${_dll}" $<TARGET_FILE_DIR:${target}>)
      endif()
    endforeach()
  endif()
endfunction()

enable_testing()
add_subdirectory(apps/hello-window)
