#include <CLI11.hpp>
#include <SDL3/SDL.h>

#include <cstdint>
#include <cstdio>
#include <memory>
#include <optional>

namespace
{

// Calls SDL_Quit when it goes out of scope. Created right after a successful SDL_Init, and declared
// before the window and renderer, so they are destroyed first (renderer, window, then SDL_Quit).
struct SdlQuitGuard
{
    ~SdlQuitGuard() { SDL_Quit(); }
};

struct WindowDeleter
{
    void operator()(SDL_Window* w) const { SDL_DestroyWindow(w); }
};
struct RendererDeleter
{
    void operator()(SDL_Renderer* r) const { SDL_DestroyRenderer(r); }
};

}  // namespace

int main(int argc, char** argv)
{
    CLI::App app{"Open an SDL3 window and clear it to a solid colour."};
    // Optional: --frames N exits after N frames (used by the headless smoke test).
    // Unsigned, so CLI11 itself rejects negative and out-of-range values. Fixed width, so the
    // accepted range is the same on every platform (unsigned long is 32-bit with MSVC).
    std::optional<std::uint64_t> max_frames;
    app.add_option("--frames", max_frames, "Exit after N frames")->type_name("N");
    // On a bad command line print the error plus the usage, like the C# and Haskell apps do.
    app.failure_message(CLI::FailureMessage::help);
    // Prints the error (or --help text) and returns early; nothing is initialised yet.
    CLI11_PARSE(app, argc, argv);

    if (!SDL_Init(SDL_INIT_VIDEO))
    {
        std::fprintf(stderr, "SDL_Init failed: %s\n", SDL_GetError());
        return 1;
    }
    SdlQuitGuard sdl;

    SDL_Window* raw_window = nullptr;
    SDL_Renderer* raw_renderer = nullptr;
    if (!SDL_CreateWindowAndRenderer("hello-window", 800, 600, 0, &raw_window, &raw_renderer))
    {
        std::fprintf(stderr, "SDL_CreateWindowAndRenderer failed: %s\n", SDL_GetError());
        return 1;
    }
    std::unique_ptr<SDL_Window, WindowDeleter> window{raw_window};
    std::unique_ptr<SDL_Renderer, RendererDeleter> renderer{raw_renderer};

    bool running = true;
    for (std::uint64_t frame = 0; running && (!max_frames || frame != *max_frames); ++frame)
    {
        SDL_Event e;
        while (SDL_PollEvent(&e))
        {
            if (e.type == SDL_EVENT_QUIT ||
                (e.type == SDL_EVENT_KEY_DOWN && e.key.key == SDLK_ESCAPE))
            {
                running = false;
            }
        }
        SDL_SetRenderDrawColor(renderer.get(), 30, 60, 120, 255);
        SDL_RenderClear(renderer.get());
        SDL_RenderPresent(renderer.get());
    }

    // Scope exit destroys the renderer, then the window, then calls SDL_Quit.
    return 0;
}
