# Cross-Language Benchmarking

A common result schema (`shared/bench-schema/result.schema.json`) lets every language's benchmark output be compared directly:

```json
{
  "language": "cpp",
  "scalar_type": "float",
  "benchmark": "vec3_add",
  "iterations": 1000000,
  "mean_ns": 2.1,
  "stddev_ns": 0.3,
  "commit": "abc123"
}
```

Each language's `bench/` target writes results matching this schema to `shared/bench-results/<lang>-<date>.json`. The top-level `bench.sh`:

1. Runs (or collects already-run) results from each language.
2. Feeds them into a small aggregator script (language-agnostic choice — e.g. Python, since it isn't one of the three under comparison) that produces comparison tables/charts per benchmark, across language × scalar-type.

**Recommended timing libraries** (handle warmup, statistical noise, outliers — avoid hand-rolled timing loops):
- C++: Google Benchmark
- C#: BenchmarkDotNet
- Haskell: `criterion` or `tasty-bench`
