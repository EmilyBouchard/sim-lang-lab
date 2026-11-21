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
- **Reproducible:** simulations are deterministic, CI never uses the network, and
  every language writes benchmark results in one shared format.

## Getting started

> The project is at Tier 0, so the language directories and build scripts below
> don't exist yet.

### Prerequisites

| Language | Toolchain |
|---|---|
| C++ | A C++20 compiler (GCC or Clang), CMake with presets |
| C# | .NET SDK (needed for generic math, `INumber<T>`) |
| Haskell | GHC + Cabal (or Stack), [`sdl3-hs`](https://github.com/klukaszek/sdl3-hs) |
| All | SDL 3.4, SQLite 3 |
| Benchmark reports | Python 3 |

### Build and test

```bash
git clone https://github.com/EmilyBouchard/sim-lang-lab.git
cd sim-lang-lab

./build.sh all              # build every language
./build.sh cpp --test       # build and test one language
./build.sh haskell math     # build a single library or app
./bench.sh                  # run benchmarks and compare languages
```

You can also build each language directory directly with its own tools
(`cmake`, `dotnet`, `cabal`). See
[`docs/architecture/build-orchestration.md`](/docs/architecture/build-orchestration.md).

## Documentation

| Document | Contents |
|---|---|
| [`docs/project-roadmap.md`](/docs/project-roadmap.md) | Project tiers in order of difficulty, with goals and acceptance criteria |
| [`docs/architecture/`](/docs/architecture/README.md) | How the repository is organized, with one file per topic (layout, math, data, build, CI, benchmarks) |
| [`docs/architecture/open-items.md`](/docs/architecture/open-items.md) | Open decisions |
| [`CLAUDE.md`](/CLAUDE.md) | Instructions for the Claude Code assistant (coach role) |
