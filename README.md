# sim-lang-lab

A lab for learning **Haskell** and getting better at **C++** and **C#** by building
the same simulation projects in all three languages, then comparing and
benchmarking them.

The projects get harder as they go. They start with an SDL3 window and a
hand-rolled math library, move on to physics, a small UI toolkit and a
JPL/SQLite data pipeline, and end with N-body gravity simulations: brute force,
then Barnes-Hut, then the Fast Multipole Method, in 2D and 3D.

## Principles

- **Fair comparison:** `cpp/`, `csharp/` and `haskell/` are separate build roots
  with no dependencies on each other, and each one implements the same features.
- **Hand-rolled math:** vectors, matrices and quaternions are written from
  scratch in each language, and every type works with both `float` and `double`.
- **Reproducible:** simulations are deterministic, the tests never use the network (JPL data comes only from committed reference files), and
  every language writes benchmark results in one shared format.

## Getting started

> The project is at Tier 0. The language directories and the build scripts
> (`build.sh`, `build.ps1`, `format.sh`) exist, but so far the only app is
> `hello-window` (stage 0.1). The libraries (`math`, `sdl-platform`, ...) and
> `bench.sh` don't exist yet.

### Prerequisites

| Language | Toolchain |
|---|---|
| C++ | A C++23 compiler (GCC or Clang on Linux; MSVC on Windows), CMake 3.28+ with presets, Ninja |
| C# | .NET SDK (needed for generic math, `INumber<T>`); the projects target `net10.0` |
| Haskell | GHC 9.10.3 (pinned in `haskell/cabal.project`) + Cabal 3.16, [`sdl3-hs`](https://github.com/klukaszek/sdl3-hs) (git submodule, see below) |
| All | SDL 3.4 (installed for you by vcpkg), SQLite 3 |
| Benchmark reports | Python 3 |

### Windows

Run the build from PowerShell with `.\build.ps1` (see below). You need:

- **Visual Studio 2022 or newer (or Build Tools) with the "Desktop development with C++" workload.**
  `build.ps1` finds it with `vswhere` and loads the MSVC x64 environment through
  `scripts/vsenv.ps1`, so you don't need a Developer prompt.
- CMake, Ninja, the .NET SDK, and GHC + Cabal (for example from [ghcup](https://www.haskell.org/ghcup/)) on `PATH`.
- Git for Windows (the pre-commit hook runs under its bundled `sh`).

If PowerShell refuses to run the script, allow local scripts once with
`Set-ExecutionPolicy -Scope CurrentUser RemoteSigned`, or run
`powershell -ExecutionPolicy Bypass -File .\build.ps1 all -Test`.

The build puts `SDL3.dll` next to each executable, so the apps run by double-click or from any shell,
without the vcpkg setup: CMake copies it for C++ (plus the ASan runtime in debug builds), the `.csproj`
copies it for C#, and `build.ps1` copies it for Haskell, because cabal has no post-build step. If you
build Haskell with plain `cabal build`, run `.\build.ps1 haskell` once to refresh the copy.

### SDL3 (vcpkg)

SDL3 is installed by a vcpkg submodule at a pinned version, so all three languages build
against the same library. `./build.sh` does this automatically on first use (the first build
takes a few minutes, since SDL3 is built from source). On Linux you need a few system
packages first, such as `zip`, `autoconf`, `autoconf-archive`, `automake`, `libtool` and the
X11/Wayland dev packages. See [`docs/architecture/dependencies.md`](/docs/architecture/dependencies.md).

### Submodules

This repo has two submodules: `vendor/vcpkg` (see above), and `sdl3-hs`, which is not on
Hackage, so it is vendored at `haskell/vendor/sdl3-hs` and built as part of the Haskell project
(`haskell/cabal.project`). If you cloned without `--recurse-submodules`, run:

```bash
git submodule update --init
```

`build.sh` and `build.ps1` run this for you on every build.

To move to a newer `sdl3-hs`, update the submodule and commit the new pointer
deliberately, so the pinned version only changes on purpose.

### Build and test

```bash
git clone --recurse-submodules https://github.com/EmilyBouchard/sim-lang-lab.git
cd sim-lang-lab

./build.sh all                              # build every language
./build.sh cpp --test                       # build and smoke-test one language
./build.sh haskell apps/hello-window --run  # build and run a single app (opens a window)
./build.ps1 all -Test                       # same on Windows (PowerShell)
./bench.sh                                  # (planned) run benchmarks and compare languages
```

`hello-window` takes `--frames N` (exit after N frames; the smoke test uses it) and `--help` in all three
languages. A bad value is reported with a message and a non-zero exit before SDL starts. See
[`docs/architecture/dependencies.md`](/docs/architecture/dependencies.md) for the parsing libraries.

You can also build each language directory directly with its own tools
(`cmake`, `dotnet`, `cabal`). See
[`docs/architecture/build-orchestration.md`](/docs/architecture/build-orchestration.md).

### Formatting and git hooks

Each language has its own formatter config:

| Language | Formatter | Config |
|---|---|---|
| C++ | `clang-format` | `cpp/.clang-format` |
| C# | `dotnet format` | `.editorconfig`, `csharp/.editorconfig` |
| Haskell | `fourmolu` | `haskell/fourmolu.yaml` |

```bash
./format.sh                 # format every language
./format.sh cpp             # format one language
./format.sh all --check     # check only, change nothing
.\format.ps1 all -Check        # same on Windows (PowerShell; runs format.sh through Git's bash)
```

A `pre-commit` hook in `.githooks/` runs `./format.sh <lang> --check` for each
language with staged changes, and blocks the commit if the check fails. Git
doesn't copy hook settings when you clone, so enable it once per clone:

```bash
git config core.hooksPath .githooks
```

It works on Linux and on Windows (Git for Windows runs it with its bundled
`sh` and `bash`). On Windows you still need `clang-format`, `fourmolu` and the
.NET SDK on your `PATH`. To fix a failed check, run `./format.sh`, stage the
changes and commit again. To skip the hook in an emergency, use
`git commit --no-verify`.

## Documentation

| Document | Contents |
|---|---|
| [`docs/project-roadmap.md`](/docs/project-roadmap.md) | Project tiers in order of difficulty, with goals and acceptance criteria |
| [`docs/architecture/`](/docs/architecture/README.md) | How the repository is organized, with one file per topic (layout, math, data, build, CI, benchmarks) |
| [`docs/architecture/open-items.md`](/docs/architecture/open-items.md) | Open decisions |
| [`CLAUDE.md`](/CLAUDE.md) | Instructions for the Claude Code assistant (coach role) |
