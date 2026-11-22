#!/usr/bin/env python3
"""Check hello-window's command-line contract, for any of the three language implementations.

    check_hello_window_cli.py -- <command to start the app> [fixed args...]

Examples:
    check_hello_window_cli.py -- cpp/build/debug/apps/hello-window/hello-window
    check_hello_window_cli.py -- dotnet run --project Apps/HelloWindow --no-build --
    check_hello_window_cli.py -- cabal run -v0 hello-window --

The contract (see docs/architecture/dependencies.md, "Command-line parsing"):
  * --help prints usage and exits 0.
  * --frames N with a non-negative integer runs N frames and exits 0.
  * A bad or missing value, or an unknown option, is rejected: non-zero exit, a message that names
    the offending text, and the usage. The app must not hang, and must fail before SDL starts.

Only the standard library is used. Exits 0 if every case passes, 1 otherwise.
"""
import os
import subprocess
import sys

TIMEOUT_SECONDS = 120  # generous: `cabal run` / `dotnet run` start-up is included

# The program description. All three apps print it as part of their help/usage block (C++ and C#
# print the whole help, Haskell prints the usage line and the description), and a bare error
# message does not contain it, so it shows that the usage was printed along with the error.
USAGE_MARKER = "Open an SDL3 window and clear it to a solid colour."

# (arguments, should_succeed, text that must appear in the combined output)
CASES = [
    (["--help"], True, ["--frames", "Exit after N frames", USAGE_MARKER]),
    (["--frames", "0"], True, []),
    (["--frames", "5"], True, []),
    (["--frames", "abc"], False, ["abc"]),
    (["--frames", "5x"], False, ["5x"]),
    (["--frames", "-3"], False, ["-3"]),
    (["--frames", "99999999999999999999"], False, ["99999999999999999999"]),
    (["--frames"], False, ["--frames"]),
    (["--frame", "5"], False, ["--frame"]),
]


def run_case(command, args, should_succeed, must_contain):
    env = dict(os.environ)
    # Headless: a valid run must work without a display.
    env.setdefault("SDL_VIDEO_DRIVER", "dummy")
    env.setdefault("SDL_RENDER_DRIVER", "software")
    try:
        proc = subprocess.run(
            command + args,
            stdin=subprocess.DEVNULL,
            capture_output=True,
            timeout=TIMEOUT_SECONDS,
            env=env,
        )
    except subprocess.TimeoutExpired:
        return "timed out (the app hung instead of exiting)"
    except OSError as exc:
        return f"could not start the app: {exc}"

    output = (proc.stdout + proc.stderr).decode("utf-8", errors="replace")
    if should_succeed:
        if proc.returncode != 0:
            return f"expected exit 0, got {proc.returncode}: {output.strip()[:200]}"
    else:
        if proc.returncode == 0:
            return "expected a non-zero exit, but the bad input was accepted"
        if USAGE_MARKER not in output:
            return f"the error did not include the usage listing: {output.strip()[:200]}"
        if "SDL_Init" in output or "SDL_CreateWindow" in output:
            return "the app reached SDL before rejecting the arguments"
    for text in must_contain:
        if text not in output:
            return f"expected the output to mention {text!r}: {output.strip()[:200]}"
    return None


def main(argv):
    if "--" not in argv:
        print(__doc__, file=sys.stderr)
        return 2
    command = argv[argv.index("--") + 1 :]
    if not command:
        print("no command given after --", file=sys.stderr)
        return 2

    failures = 0
    for args, should_succeed, must_contain in CASES:
        problem = run_case(command, args, should_succeed, must_contain)
        label = "accepts" if should_succeed else "rejects"
        shown = " ".join(args) or "(no arguments)"
        if problem is None:
            print(f"  ok    {label} {shown}")
        else:
            failures += 1
            print(f"  FAIL  {label} {shown}: {problem}")
    print(f"{len(CASES) - failures}/{len(CASES)} cases passed")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
