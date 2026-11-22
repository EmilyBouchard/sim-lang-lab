#!/usr/bin/env bash
# Fetch, bootstrap and run vcpkg to install the pinned SDL3 (see vcpkg.json).
# Idempotent: does nothing when vcpkg.json and the vcpkg checkout are unchanged
# (tracked by a stamp file in vcpkg_installed/). On a cache hit it never touches the network.
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=env.sh
. "$root/scripts/env.sh"

vcpkg_dir="$root/vendor/vcpkg"
git -C "$root" submodule update --init vendor/vcpkg   # offline and instant when up to date

vcpkg_rev="$(git -C "$vcpkg_dir" rev-parse HEAD)"
# The manifest's builtin-baseline must be the vendor/vcpkg commit, or vcpkg resolves versions
# against a different registry snapshot than the one we bootstrap.
baseline="$(sed -n 's/.*"builtin-baseline"[[:space:]]*:[[:space:]]*"\([0-9a-f]*\)".*/\1/p' "$root/vcpkg.json")"
if [[ "$baseline" != "$vcpkg_rev" ]]; then
  echo "setup-deps: vcpkg.json builtin-baseline ($baseline) does not match vendor/vcpkg ($vcpkg_rev)." >&2
  echo "            Update the baseline (see docs/architecture/dependencies.md, \"Upgrading SDL3\")." >&2
  exit 1
fi

stamp="$root/vcpkg_installed/.stamp-$SIM_VCPKG_TRIPLET"
want="$(cksum < "$root/vcpkg.json") $vcpkg_rev"
if [[ -f "$stamp" && "$(cat "$stamp")" == "$want" && -d "$SIM_VCPKG_PREFIX/share/sdl3" ]]; then
  exit 0
fi

# (Re)bootstrap the vcpkg tool if it is missing or the pinned tool version changed.
tool_stamp="$root/vcpkg_installed/.tool-stamp"
tool_want="$(cksum < "$vcpkg_dir/scripts/vcpkg-tool-metadata.txt")"
if [[ ! -x "$vcpkg_dir/vcpkg" || ! -f "$tool_stamp" || "$(cat "$tool_stamp")" != "$tool_want" ]]; then
  "$vcpkg_dir/bootstrap-vcpkg.sh" -disableMetrics
  mkdir -p "$root/vcpkg_installed"
  echo "$tool_want" > "$tool_stamp"
fi

echo "setup-deps: installing vcpkg dependencies ($SIM_VCPKG_TRIPLET)..."
VCPKG_DISABLE_METRICS=1 "$vcpkg_dir/vcpkg" install \
  --triplet "$SIM_VCPKG_TRIPLET" \
  --x-manifest-root="$root" \
  --x-install-root="$root/vcpkg_installed"
mkdir -p "$root/vcpkg_installed"
echo "$want" > "$stamp"
