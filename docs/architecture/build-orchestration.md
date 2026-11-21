# Build Orchestration

The top-level script dispatches to each language's native tooling — it does not reimplement building.

```bash
./build.sh all                      # every language, every project
./build.sh cpp                      # everything under cpp/
./build.sh csharp Apps.ParticleDemo # one project
./build.sh haskell math              # one library/component
./build.sh all --test               # build + run all unit + integration tests
./build.sh cpp --bench               # build + run cpp benchmarks only
```

Dispatch table:
- `cpp` → CMake presets (`cmake --build`, `ctest`)
- `csharp` → `dotnet build` / `dotnet test` on the target project
- `haskell` → `stack build` / `cabal test` with a component target

Each language subdirectory remains independently buildable (`cd cpp && cmake --build .`) — the root script is a convenience wrapper, never a hidden dependency.
