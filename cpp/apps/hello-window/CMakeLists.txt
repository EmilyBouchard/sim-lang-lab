add_executable(hello-window src/main.cpp)
target_link_libraries(hello-window PRIVATE SDL3::SDL3 CLI11::CLI11)
sim_copy_runtime_dlls(hello-window)

# Headless smoke test: dummy video driver, exits by itself after a few frames.
add_test(NAME hello-window-smoke COMMAND hello-window --frames 5)
set_tests_properties(hello-window-smoke PROPERTIES
  ENVIRONMENT "SDL_VIDEO_DRIVER=dummy;SDL_RENDER_DRIVER=software"
  TIMEOUT 30)

# Command-line handling: the same script checks the C# and Haskell apps too (exit code, message,
# usage, no hang). It lives in the repo-level scripts/ folder and needs Python 3.
find_package(Python3 COMPONENTS Interpreter)
if(Python3_FOUND)
  add_test(NAME hello-window-cli
           COMMAND ${Python3_EXECUTABLE} -I ${CMAKE_SOURCE_DIR}/../scripts/check_hello_window_cli.py
                   -- $<TARGET_FILE:hello-window>)
  set_tests_properties(hello-window-cli PROPERTIES TIMEOUT 300)
else()
  message(WARNING "Python 3 not found: the hello-window-cli test is not defined.")
endif()
