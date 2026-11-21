add_executable(hello-window src/main.cpp)
target_link_libraries(hello-window PRIVATE SDL3::SDL3)

# Headless smoke test: dummy video driver, exits by itself after a few frames.
add_test(NAME hello-window-smoke COMMAND hello-window --frames 5)
set_tests_properties(hello-window-smoke PROPERTIES
  ENVIRONMENT "SDL_VIDEO_DRIVER=dummy;SDL_RENDER_DRIVER=software")
