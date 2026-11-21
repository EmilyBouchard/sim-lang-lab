# CI (GitHub Actions)

One workflow per language, path-filtered so changes in one language don't trigger another's pipeline:

```yaml
# cpp.yml
on:
  push:
    paths: ['cpp/**', 'shared/**']
  pull_request:
    paths: ['cpp/**', 'shared/**']
```

Every workflow checks out submodules and runs the shared `.github/actions/setup-deps` action, which installs the system packages vcpkg needs and builds the pinned SDL3 (cached). See [`dependencies.md`](/docs/architecture/dependencies.md).

Each per-language workflow: build all libs → run unit tests → run integration tests → optional quick benchmark smoke-test (confirms bench binaries run, not a full perf run).

Full benchmark runs live in a separate `benchmarks.yml`, triggered manually or on a schedule — not blocking every PR with multi-minute perf runs.

The JPL snapshot tool's CI path exercises only its parser against committed fixture responses and validates the committed reference `.db` files' schema — it never makes a live network call.
