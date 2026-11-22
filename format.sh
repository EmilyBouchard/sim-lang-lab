#!/usr/bin/env bash
# Format all languages. Usage: ./format.sh [cpp|csharp|haskell|all] [--check]
# --check verifies formatting without changing files (for CI).
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
usage() { echo "usage: $0 [cpp|csharp|haskell|all] [--check]" >&2; exit 2; }
# One optional language and an optional --check, in any order. Anything else is an error: a typo
# such as `--chek` must not fall through and reformat files in place.
lang=""; check=0
for a in "$@"; do
  case "$a" in
    --check) check=1 ;;
    cpp|csharp|haskell|all) [[ -z "$lang" ]] || usage; lang="$a" ;;
    *) usage ;;
  esac
done
lang="${lang:-all}"

fmt_cpp() {
  cd "$root/cpp"
  mapfile -t files < <(git ls-files '*.cpp' '*.hpp' '*.h' '*.cc')
  (( ${#files[@]} )) || return 0
  if (( check )); then clang-format --dry-run --Werror "${files[@]}"; else clang-format -i "${files[@]}"; fi
}
fmt_csharp() {
  cd "$root/csharp"
  local extra=(--no-restore); (( check )) && extra+=(--verify-no-changes)
  dotnet format whitespace SimLangLab.sln "${extra[@]}"
  dotnet format style SimLangLab.sln "${extra[@]}"
}
fmt_haskell() {
  cd "$root/haskell"
  mapfile -t files < <(git ls-files '*.hs')
  (( ${#files[@]} )) || return 0
  if (( check )); then fourmolu --mode check "${files[@]}"; else fourmolu --mode inplace "${files[@]}"; fi
}

case "$lang" in
  cpp) fmt_cpp ;; csharp) fmt_csharp ;; haskell) fmt_haskell ;;
  all) (fmt_cpp); (fmt_csharp); (fmt_haskell) ;;
  *) usage ;;
esac
