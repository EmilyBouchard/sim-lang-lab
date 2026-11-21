#include <SDL3/SDL.h>

#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <memory>

namespace {

struct WindowDeleter {
    void operator()(SDL_Window* w) const { SDL_DestroyWindow(w); }
};
struct RendererDeleter {
    void operator()(SDL_Renderer* r) const { SDL_DestroyRenderer(r); }
};

}  // namespace

int main(int argc, char** argv) {
    // Optional: --frames N exits after N frames (used by the headless smoke test).
    long max_frames = -1;
    for (int i = 1; i + 1 < argc; ++i) {
        if (std::strcmp(argv[i], "--frames") == 0) max_frames = std::strtol(argv[i + 1], nullptr, 10);
    }

    if (!SDL_Init(SDL_INIT_VIDEO)) {
        std::fprintf(stderr, "SDL_Init failed: %s\n", SDL_GetError());
        return 1;
    }

    SDL_Window* raw_window = nullptr;
    SDL_Renderer* raw_renderer = nullptr;
    if (!SDL_CreateWindowAndRenderer("hello-window", 800, 600, 0, &raw_window, &raw_renderer)) {
        std::fprintf(stderr, "SDL_CreateWindowAndRenderer failed: %s\n", SDL_GetError());
        SDL_Quit();
        return 1;
    }
    std::unique_ptr<SDL_Window, WindowDeleter> window{raw_window};
    std::unique_ptr<SDL_Renderer, RendererDeleter> renderer{raw_renderer};

    bool running = true;
    for (long frame = 0; running && frame != max_frames; ++frame) {
        SDL_Event e;
        while (SDL_PollEvent(&e)) {
            if (e.type == SDL_EVENT_QUIT || (e.type == SDL_EVENT_KEY_DOWN && e.key.key == SDLK_ESCAPE)) {
                running = false;
            }
        }
        SDL_SetRenderDrawColor(renderer.get(), 30, 60, 120, 255);
        SDL_RenderClear(renderer.get());
        SDL_RenderPresent(renderer.get());
    }

    // Destroy renderer/window before SDL_Quit.
    renderer.reset();
    window.reset();
    SDL_Quit();
    return 0;
}
