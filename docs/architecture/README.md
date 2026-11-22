# Architecture

How the repository is organized and why. Each file covers one topic.

| File | Covers |
|---|---|
| [`docs/architecture/goals.md`](/docs/architecture/goals.md) | Design goals that drive the structure |
| [`docs/architecture/top-level-layout.md`](/docs/architecture/top-level-layout.md) | Root directory tree and `shared/` |
| [`docs/architecture/language-layout.md`](/docs/architecture/language-layout.md) | Inside `cpp/`, `csharp/`, `haskell/` |
| [`docs/architecture/math-precision.md`](/docs/architecture/math-precision.md) | Float/double switching per language |
| [`docs/architecture/data-pipeline.md`](/docs/architecture/data-pipeline.md) | SQLite schema contract, JPL reference epochs |
| [`docs/architecture/dependencies.md`](/docs/architecture/dependencies.md) | Pinned SDL3 via vcpkg, shared by all languages |
| [`docs/architecture/build-orchestration.md`](/docs/architecture/build-orchestration.md) | `build.sh` and per-language dispatch |
| [`docs/architecture/ci.md`](/docs/architecture/ci.md) | GitHub Actions workflows |
| [`docs/architecture/benchmarking.md`](/docs/architecture/benchmarking.md) | Bench result schema, aggregation, timing libraries |
| [`docs/architecture/open-items.md`](/docs/architecture/open-items.md) | Unresolved architecture decisions |

The project roadmap lives separately in [`docs/project-roadmap.md`](/docs/project-roadmap.md).
