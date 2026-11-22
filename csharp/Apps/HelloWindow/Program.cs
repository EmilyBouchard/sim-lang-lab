using System.CommandLine;
using System.Globalization;
using SDL3;

namespace SimLab.HelloWindow;

internal static class Program
{
    private static int Main(string[] args)
    {
        // Optional: --frames N exits after N frames (used by the headless smoke test).
        var frames = new Option<long?>("--frames")
        {
            Description = "Exit after N frames",
            HelpName = "N",
            Arity = ArgumentArity.ExactlyOne,
            // NumberStyles.None accepts digits only: no sign, whitespace or hex, so "-3", "5x" and
            // "0x10" are all errors. Overflow fails TryParse too.
            CustomParser = result =>
            {
                string text = result.Tokens[0].Value;
                if (long.TryParse(text, NumberStyles.None, CultureInfo.InvariantCulture, out long n))
                    return n;
                result.AddError($"--frames expects a non-negative integer, got '{text}'.");
                return null;
            },
        };

        var root = new RootCommand("Open an SDL3 window and clear it to a solid colour.") { frames };
        root.SetAction(parseResult => Run(parseResult.GetValue(frames)));

        // Invoke() prints --help, or the parse errors plus usage, and returns the exit code.
        // On a bad command line the action never runs, so nothing has been initialised.
        return root.Parse(args).Invoke();
    }

    private static int Run(long? maxFrames)
    {
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
                RunLoop(renderer, maxFrames);
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
    }

    private static void RunLoop(nint renderer, long? maxFrames)
    {
        bool running = true;
        for (long frame = 0; running && (maxFrames is null || frame != maxFrames); frame++)
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
}
