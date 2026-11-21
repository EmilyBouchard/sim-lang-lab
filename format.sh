#!/usr/bin/env bash
# Format all languages. Usage: ./format.sh [cpp|csharp|haskell|all] [--check]
# --check verifies formatting without changing files (for CI).
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
lang="${1:-all}"; check=0
for a in "$@"; do [[ "$a" == "--check" ]] && check=1; done
[[ "$lang" == "--check" ]] && lang=all

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
  *) echo "usage: $0 [cpp|csharp|haskell|all] [--check]" >&2; exit 2 ;;
esac
