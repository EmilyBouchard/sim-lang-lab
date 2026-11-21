# Per-Language Layout

Structure shown for C++; C#/Haskell mirror this shape using their native idioms (see notes below).

```
cpp/
├── CMakeLists.txt                # top-level for this language
├── libs/
│   ├── math/                     # hand-rolled vec/mat/quat, float & double
│   │   ├── include/math/
│   │   ├── src/
│   │   └── tests/
│   ├── sdl-platform/              # thin wrapper: window, input, render context
│   │   ├── include/
│   │   ├── src/
│   │   └── tests/
│   ├── ui/                        # simple UI framework, built on sdl-platform
│   │   ├── include/
│   │   ├── src/
│   │   └── tests/
│   └── data/                      # SQLite wrapper / repository layer
│       ├── include/
│       ├── src/
│       └── tests/
├── apps/
│   ├── particle-demo/
│   │   ├── src/
│   │   └── tests/                 # integration tests for this app
│   ├── physics-sandbox/
│   └── ...
├── tools/
│   ├── jpl-snapshot/               # fetches JPL data, writes SQLite (reference-epoch mode by default)
│   └── dataset-generator/          # parameterized random N-body dataset generator, writes SQLite
└── bench/
    ├── math-bench/                 # vec add, mat mul, quat slerp — float vs double
    ├── render-bench/
    └── CMakeLists.txt
```

**C# equivalent:** a solution with `Math`, `SdlPlatform`, `Ui`, `Data` class library projects; `Apps/*` and `Tools/*` executable projects; a `*.Tests` project per library/app (xUnit or similar).

**Haskell equivalent:** a single Cabal/Stack project with internal libraries (`math`, `sdl-platform`, `ui`, `data`) as separate components in one `.cabal` file (or separate packages in a Stack multi-package setup); executables under `app/` (including the JPL snapshot and dataset generator tools); a test suite per component.
