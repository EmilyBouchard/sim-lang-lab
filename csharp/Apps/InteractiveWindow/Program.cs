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

    static readonly SDL.FColor _circleColor = new()
    {
        R = 0,
        G = 0,
        B = 1,
        A = 1,
    };

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
                TexCoord = new SDL.FPoint { X = 0, Y = 0 },
            };
        }
    }

    enum Direction : byte
    {
        Up,
        Down,
        Left,
        Right,
    };

    record struct HeldDirections(bool Up, bool Down, bool Left, bool Right);

    abstract record InputAction;

    sealed record QuitAction : InputAction;

    sealed record MouseToAction(Point Point) : InputAction;

    sealed record DirectionAction(Direction Direction, bool Pressed) : InputAction;

    class World
    {
        public bool QuitRequested = false;
        public HeldDirections HeldDirections = new();
        public Point CirclePosition = new(_windowWidth / 2.0, _windowHeight / 2.0);
        public Point CircleDirection = new(160, 100);
        public double CircleRadius = 50;
        public Point SquarePosition = new(100, 100);
        public Point TrianglePosition = new(_windowWidth / 2.0, _windowHeight / 2.0);

        public void Step(double dt)
        {
            BounceMoveCircle(dt);
            MoveSquare(dt);
        }
        private void BounceMoveCircle(double dt)
        {
            static double reflect(double lo, double hi, double pos, double vel)
            {
                if (vel < 0 && pos <= lo)
                    return -vel;
                if (vel > 0 && pos >= hi)
                    return -vel;
                return vel;
            }
            CircleDirection.X = reflect(CircleRadius, _windowWidth - CircleRadius, CirclePosition.X, CircleDirection.X);
            CircleDirection.Y = reflect(CircleRadius, _windowHeight - CircleRadius, CirclePosition.Y, CircleDirection.Y);

            CirclePosition.X += CircleDirection.X * dt;
            CirclePosition.Y += CircleDirection.Y * dt;
        }

        private void MoveSquare(double dt)
        {
            Point squareDir = HeldToDir(HeldDirections);
            SquarePosition = new Point(SquarePosition.X + squareDir.X * dt * _rectangleSpeed, SquarePosition.Y + squareDir.Y * dt * _rectangleSpeed);
        }
    };

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

            if (!SDL.SetRenderVSync(renderer, 1))
            {
                Console.Error.WriteLine($"SDL_SetRenderVSync failed: {SDL.GetError()}");
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
        var world = new World { };
        ulong? prevTick = null;
        while (true)
        {
            InputAction[] actions = [.. DrainEvents().Select(FromSDLEvent).OfType<InputAction>()];
            world = actions.Aggregate(world, ApplyAction);

            if (world.QuitRequested)
                break;

            ulong currentTick = SDL.GetTicksNS();
            double dt = 1.0 * (currentTick - prevTick) / SDL.NsPerSecond ?? 0;
            world.Step(dt);

            var rect = new SDL.FRect
            {
                W = 100,
                H = 100,
                X = (float)world.SquarePosition.X,
                Y = (float)world.SquarePosition.Y,
            };

            SDL.FPoint[] triangle = [.. TrianglePoints(world.TrianglePosition, 30).Select(Point.toFPoint)];

            SDL.Vertex[] circle = [.. CircleTriangles(world.CirclePosition, world.CircleRadius).Select(p => Point.toVertex(p, _circleColor))];

            SDL.SetRenderDrawColor(renderer, 45, 45, 45, 255);
            SDL.RenderClear(renderer);
            SDL.RenderGeometry(renderer, 0, circle, circle.Length, 0, 0);
            SDL.SetRenderDrawColor(renderer, 0, 255, 0, 255); // green square
            SDL.RenderFillRect(renderer, rect);
            SDL.SetRenderDrawColor(renderer, 255, 0, 0, 255);
            SDL.RenderLines(renderer, triangle, triangle.Length);
            SDL.RenderPresent(renderer);

            prevTick = currentTick;
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
            points[k + 1] = PointN(i + 1);
            points[k + 2] = origin;
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

    private static InputAction? FromSDLEvent(SDL.Event e)
    {
        return (SDL.EventType)e.Type switch
        {
            SDL.EventType.Quit => new QuitAction { },
            SDL.EventType.KeyDown => FromKeycode(e.Key, true) ?? FromScancode(e.Key, true),
            SDL.EventType.KeyUp => FromKeycode(e.Key, false) ?? FromScancode(e.Key, false),
            SDL.EventType.MouseMotion => new MouseToAction(new Point(e.Motion.X, e.Motion.Y)),
            _ => null,
        };
    }

    private static InputAction? FromKeycode(SDL.KeyboardEvent e, bool pressed)
    {
        return e.Key switch
        {
            SDL.Keycode.Escape => new QuitAction { },
            SDL.Keycode.Up => new DirectionAction(Direction.Up, pressed),
            SDL.Keycode.Down => new DirectionAction(Direction.Down, pressed),
            SDL.Keycode.Left => new DirectionAction(Direction.Left, pressed),
            SDL.Keycode.Right => new DirectionAction(Direction.Right, pressed),
            _ => null,
        };
    }

    private static InputAction? FromScancode(SDL.KeyboardEvent e, bool pressed)
    {
        return e.Scancode switch
        {
            SDL.Scancode.W => new DirectionAction(Direction.Up, pressed),
            SDL.Scancode.S => new DirectionAction(Direction.Down, pressed),
            SDL.Scancode.A => new DirectionAction(Direction.Left, pressed),
            SDL.Scancode.D => new DirectionAction(Direction.Right, pressed),
            _ => null,
        };
    }

    private static World ApplyAction(World world, InputAction action)
    {
        switch (action)
        {
            case QuitAction:
                world.QuitRequested = true;
                break;
            case MouseToAction(var p):
                world.TrianglePosition = p;
                break;
            case DirectionAction(var dir, var pressed):
                switch (dir)
                {
                    case Direction.Up:
                        world.HeldDirections.Up = pressed;
                        break;
                    case Direction.Down:
                        world.HeldDirections.Down = pressed;
                        break;
                    case Direction.Left:
                        world.HeldDirections.Left = pressed;
                        break;
                    case Direction.Right:
                        world.HeldDirections.Right = pressed;
                        break;
                }
                break;
            default:
                throw new ArgumentOutOfRangeException(nameof(action));
        }

        return world;
    }

    private static Point HeldToDir(HeldDirections held)
    {
        static double valOf(bool pressed) => pressed ? 1 : 0;

        var dir = new Point(valOf(held.Right) - valOf(held.Left), valOf(held.Down) - valOf(held.Up));
        if (dir.X != 0 && dir.Y != 0)
        {
            dir.X *= _rsqrt2;
            dir.Y *= _rsqrt2;
        }

        return dir;
    }
}
