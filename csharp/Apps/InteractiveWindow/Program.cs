using System.CommandLine;
using SDL3;

namespace SimLab.InteractiveWindow;

internal static class Program
{
    const string _windowTitle = "interactive-window";
    const int _windowWidth = 800;
    const int _windowHeight = 600;
    const SDL.WindowFlags _windowFlags = 0;

    const double _fpsWindow = 0.5;

    const double _rectangleSpeed = 200;

    const double _rsqrt2 = 0.7071067811865475;

    record struct Point(double X, double Y)
    {
        public static SDL.FPoint toFPoint(Point p)
        {
            return new SDL.FPoint
            {
                X = (float)p.X,
                Y = (float)p.Y,
            };
        }

        public static SDL.Vertex toVertex(Point p, SDL.FColor color)
        {
            return new SDL.Vertex
            {
                Position = toFPoint(p),
                Color = color,
                TexCoord = new SDL.FPoint{ X = 0, Y = 0 },
            };
        }
    }

    private static int Main(string[] args)
    {
        var root = new RootCommand("Open an interactive SDL3 window drawing a circle, a rectangle, and a triangle") { };
        root.SetAction(parseResult => Run());

        return root.Parse(args).Invoke();
    }

    private static int Run()
    {
        if (!SDL.Init(SDL.InitFlags.Video))
        {
            Console.Error.WriteLine($"SDL_Init failed: {SDL.GetError()}");
            return 1;
        }

        try
        {
            if (!SDL.CreateWindowAndRenderer(_windowTitle, _windowWidth, _windowHeight, _windowFlags, out nint window, out nint renderer))
            {
                Console.Error.WriteLine($"SDL_CreateWindowAndRenderer failed: {SDL.GetError()}");
                return 1;
            }

            try
            {
                RunLoop(renderer);
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

    private static void RunLoop(nint renderer)
    {
        bool running = true;
        for (long frame = 0; running; ++frame)
        {
            while (SDL.PollEvent(out SDL.Event e))
            {
                var type = (SDL.EventType)e.Type;
                if (type == SDL.EventType.Quit ||
                        (type == SDL.EventType.KeyDown && e.Key.Key == SDL.Keycode.Escape))
                {
                    running = false;
                }
            }

            var rect = new SDL.FRect
            {
                W = 100,
                H = 100,
                X = 100,
                Y = 100,
            };

            SDL.FPoint[] triangle = [.. TrianglePoints(new Point(400, 300), 30).Select(Point.toFPoint)];

            SDL.FColor circleColor = new SDL.FColor
            {
                R = 0,
                G = 0,
                B = 1,
                A = 1,
            };
            SDL.Vertex[] circle = [.. CircleTriangles(new Point(400, 300), 50).Select(p => Point.toVertex(p, circleColor))];

            SDL.SetRenderDrawColor(renderer, 45, 45, 45, 255);
            SDL.RenderClear(renderer);
            if (!SDL.RenderGeometry(renderer, 0, circle, circle.Length, 0, 0))
            {
                Console.Error.WriteLine($"RenderGeometry failed: {SDL.GetError()}");
            }
            SDL.SetRenderDrawColor(renderer, 0, 255, 0, 255); // green square
            SDL.RenderFillRect(renderer, rect);
            SDL.SetRenderDrawColor(renderer, 255, 0, 0, 255);
            SDL.RenderLines(renderer, triangle, triangle.Length);
            SDL.RenderPresent(renderer);
        }
    }

    private static Point[] CircleTriangles(Point origin, double radius)
    {
        const int steps = 32;
        const double stepAngle = Math.PI * 2 / steps;
        var points = new Point[steps * 3];

        Point PointN(int n) => new(origin.X + radius * Math.Cos(n * stepAngle), origin.Y + radius * Math.Sin(n * stepAngle));

        for (int i = 0; i < steps; ++i)
        {
            int k = i * 3;
            points[k] = PointN(i);
            points[k+1] = PointN(i+1);
            points[k+2] = origin;
        }

        return points;
    }

    private static Point[] TrianglePoints(Point origin, double radius)
    {
        var points = new Point[4];
        for (int i = 0; i < 4; ++i)
        {
            double angle = 3 * Math.PI / 2 + i * (2 * Math.PI / 3);
            points[i] = new Point(origin.X + radius * Math.Cos(angle), origin.Y + radius * Math.Sin(angle));
        }

        return points;
    }


    private static IEnumerable<SDL.Event> DrainEvents()
    {
        while (SDL.PollEvent(out SDL.Event e))
            yield return e;
    }

}
