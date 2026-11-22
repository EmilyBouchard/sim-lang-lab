# CI (GitHub Actions)

One workflow per language (`cpp.yml`, `csharp.yml`, `haskell.yml`), plus `format.yml`. Each has a single job named after the workflow, so the check names are `cpp`, `csharp`, `haskell` and `format`.

```yaml
on:
  pull_request:
  push:
    branches: [main]
```

They run on every pull request and on pushes to `main`, with **no path filters**. The `main` branch requires these four checks (see below), and a required check that never starts, because a PR changed none of its paths, would block the merge forever. The repository is public, so Linux Actions minutes are free. Do not add Windows runners: they are billed at a higher rate.

Every language workflow checks out submodules and runs the shared `.github/actions/setup-deps` action, which installs the system packages vcpkg needs and builds the pinned SDL3 (cached). See [`dependencies.md`](/docs/architecture/dependencies.md).

Each per-language workflow: build all libs → run unit tests → run integration tests → optional quick benchmark smoke-test (confirms bench binaries run, not a full perf run).

Full benchmark runs live in a separate `benchmarks.yml`, triggered manually or on a schedule — not blocking every PR with multi-minute perf runs.

The JPL snapshot tool's CI path exercises only its parser against committed fixture responses and validates the committed reference `.db` files' schema — it never makes a live network call.

## Branch protection

`main` accepts changes only through pull requests, and a PR can merge only when `cpp`, `csharp`, `haskell` and `format` all pass. The rule also applies to repository admins, and blocks force pushes and branch deletion. No approving reviews are required (the repo has one maintainer, who cannot approve their own PR). Settings: GitHub, Settings, Branches, rule for `main`, or `gh api repos/<owner>/<repo>/branches/main/protection`.

If you rename a job or add a workflow that should be required, update the required checks in that rule too, or the PR will wait for a check that never reports.

## Formatting

`format.yml` runs `./format.sh all --check`, the same command as the pre-commit hook. It pins `clang-format` (from PyPI), `fourmolu` (the release binary, verified by SHA-256) and the .NET SDK (from `csharp/global.json`), so a file that passes locally passes in CI. When you upgrade a formatter locally, update the pin in `format.yml` in the same PR.
