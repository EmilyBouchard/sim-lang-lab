add_executable(hello-window src/main.cpp)
target_link_libraries(hello-window PRIVATE SDL3::SDL3 CLI11::CLI11)

# Headless smoke test: dummy video driver, exits by itself after a few frames.
add_test(NAME hello-window-smoke COMMAND hello-window --frames 5)
set_tests_properties(hello-window-smoke PROPERTIES
  ENVIRONMENT "SDL_VIDEO_DRIVER=dummy;SDL_RENDER_DRIVER=software"
  TIMEOUT 30)

# Argument handling. Bad input must be reported and rejected before SDL starts. The tests match
# the error text (which also proves the program did not hang); the exit code is not checked here.
function(hello_window_args_test name regex)
  add_test(NAME hello-window-args-${name} COMMAND hello-window ${ARGN})
  set_tests_properties(hello-window-args-${name} PROPERTIES PASS_REGULAR_EXPRESSION "${regex}" TIMEOUT 30)
endfunction()

hello_window_args_test(help "--frames" --help)
hello_window_args_test(not-a-number "--frames" --frames abc)
hello_window_args_test(trailing-garbage "--frames" --frames 5x)
hello_window_args_test(negative "--frames" --frames -3)
hello_window_args_test(missing-value "--frames" --frames)
hello_window_args_test(unknown-option "--frame" --frame 5)
