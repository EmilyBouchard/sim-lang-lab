# Top-Level Layout

```
/repo
├── build.sh / build.ps1          # top-level orchestrator
├── bench.sh                      # cross-language benchmark runner + report
├── docs/
│   └── decisions/                # ADRs: e.g. why float/double toggle, why this UI approach
├── .github/workflows/
│   ├── cpp.yml
│   ├── csharp.yml
│   ├── haskell.yml
│   └── benchmarks.yml            # scheduled/manual, not on every PR
├── cpp/
├── csharp/
├── haskell/
└── shared/
    ├── assets/                   # textures, fonts — shared across all languages
    ├── test-data/                # golden files, fixtures used by every language's tests
    │   └── jpl-references/       # committed JPL snapshots at fixed reference epochs
    ├── data-schema/              # shared SQLite schema (bodies.sql) for JPL + generator output
    └── bench-schema/             # common JSON schema so all languages emit comparable results
```

Each language directory is a **fully independent build root** — its own package manager, its own CI job, buildable standalone without the root script. This isolation is what keeps the comparison honest.
