#!/usr/bin/env bash
# Top-level orchestrator. Dispatches to each language's native tooling.
#   ./build.sh <cpp|csharp|haskell|all> [apps/<name>] [--test] [--run]
# --test  run the headless smoke test after building
# --run   run the app normally (opens a real window; Esc or close to quit)
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# The language is optional: a leading option (./build.sh --test) means "all", as in build.ps1.
lang=all
if [[ $# -gt 0 && "$1" != -* ]]; then lang="$1"; shift; fi
target=""; do_test=0; do_run=0
for a in "$@"; do
  case "$a" in
    --test) do_test=1 ;;
    --run)  do_run=1 ;;
    -*)     echo "unknown option: $a" >&2; exit 2 ;;
    *)      target="$a" ;;
  esac
done
app="${target#apps/}"   # e.g. hello-window ("" = everything)

# Always sync submodules (vcpkg, sdl3-hs): offline and instant when already up to date.
git -C "$root" submodule update --init
# SDL3 comes from the pinned vcpkg install (see docs/architecture/dependencies.md).
"$root/scripts/setup-deps.sh"
# shellcheck source=scripts/env.sh
. "$root/scripts/env.sh"

smoke_env=(SDL_VIDEO_DRIVER=dummy SDL_RENDER_DRIVER=software)

# Run the shared command-line contract test (scripts/check_hello_window_cli.py) against an app.
python_cmd=""
for c in python3 python; do command -v "$c" >/dev/null 2>&1 && { python_cmd="$c"; break; }; done
check_cli() {
  [[ "${app:-hello-window}" == hello-window ]] || return 0
  [[ -n "$python_cmd" ]] || { echo "Python 3 is required for --test (command-line checks)." >&2; return 1; }
  "$python_cmd" -I "$root/scripts/check_hello_window_cli.py" -- "$@"
}

build_cpp() {
  cd "$root/cpp"
  cmake --preset debug >/dev/null
  cmake --build --preset debug ${app:+--target "$app"}
  (( do_test )) && ctest --preset debug
  (( do_run )) && "build/debug/apps/${app:-hello-window}/${app:-hello-window}"
  return 0
}

pascal() { echo "$1" | sed -E 's/(^|-)([a-z])/\U\2/g'; }

build_csharp() {
  cd "$root/csharp"
  if [[ -n "$app" ]]; then proj="Apps/$(pascal "$app")/$(pascal "$app").csproj"; else proj="SimLangLab.sln"; fi
  dotnet build "$proj" --nologo -v q
  (( do_test )) && env "${smoke_env[@]}" dotnet run --project "Apps/$(pascal "${app:-hello-window}")" --no-build -- --frames 5
  (( do_test )) && check_cli dotnet run --project "Apps/$(pascal "${app:-hello-window}")" --no-build --
  (( do_run )) && dotnet run --project "Apps/$(pascal "${app:-hello-window}")" --no-build
  return 0
}

build_haskell() {
  cd "$root/haskell"
  cabal build ${app:-all}
  (( do_test )) && env "${smoke_env[@]}" cabal run -v0 "${app:-hello-window}" -- --frames 5
  (( do_test )) && check_cli cabal run -v0 "${app:-hello-window}" --
  (( do_run )) && cabal run -v0 "${app:-hello-window}"
  return 0
}

case "$lang" in
  cpp)     build_cpp ;;
  csharp)  build_csharp ;;
  haskell) build_haskell ;;
  all)     (build_cpp); (build_csharp); (build_haskell) ;;
  *) echo "usage: $0 <cpp|csharp|haskell|all> [apps/<name>] [--test] [--run]" >&2; exit 2 ;;
esac
