using SDL3;

// Optional: --frames N exits after N frames (used by the headless smoke test).
long maxFrames = -1;
for (int i = 0; i + 1 < args.Length; i++)
{
    if (args[i] == "--frames") maxFrames = long.Parse(args[i + 1]);
}

if (!SDL.Init(SDL.InitFlags.Video))
{
    Console.Error.WriteLine($"SDL_Init failed: {SDL.GetError()}");
    return 1;
}

try
{
    if (!SDL.CreateWindowAndRenderer("hello-window", 800, 600, 0, out var window, out var renderer))
    {
        Console.Error.WriteLine($"SDL_CreateWindowAndRenderer failed: {SDL.GetError()}");
        return 1;
    }

    try
    {
        bool running = true;
        for (long frame = 0; running && frame != maxFrames; frame++)
        {
            while (SDL.PollEvent(out var e))
            {
                var type = (SDL.EventType)e.Type;
                if (type == SDL.EventType.Quit ||
                    (type == SDL.EventType.KeyDown && e.Key.Key == SDL.Keycode.Escape))
                {
                    running = false;
                }
            }
            SDL.SetRenderDrawColor(renderer, 30, 60, 120, 255);
            SDL.RenderClear(renderer);
            SDL.RenderPresent(renderer);
        }
    }
    finally
    {
        SDL.DestroyRenderer(renderer);
        SDL.DestroyWindow(window);
    }
}
finally
{
    SDL.Quit();
}
return 0;
