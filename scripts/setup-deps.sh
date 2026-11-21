#!/usr/bin/env bash
# Fetch, bootstrap and run vcpkg to install the pinned SDL3 (see vcpkg.json).
# Idempotent: does nothing when vcpkg.json and the vcpkg checkout are unchanged.
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=env.sh
. "$root/scripts/env.sh"

vcpkg_dir="$root/vendor/vcpkg"
if [[ ! -f "$vcpkg_dir/bootstrap-vcpkg.sh" ]]; then
  git -C "$root" submodule update --init vendor/vcpkg
fi
if [[ ! -x "$vcpkg_dir/vcpkg" ]]; then
  "$vcpkg_dir/bootstrap-vcpkg.sh" -disableMetrics
fi

stamp="$root/vcpkg_installed/.stamp-$SIM_VCPKG_TRIPLET"
want="$(cksum < "$root/vcpkg.json") $(git -C "$vcpkg_dir" rev-parse HEAD)"
if [[ -f "$stamp" && "$(cat "$stamp")" == "$want" && -d "$SIM_VCPKG_PREFIX/share/sdl3" ]]; then
  exit 0
fi

echo "setup-deps: installing vcpkg dependencies ($SIM_VCPKG_TRIPLET)..."
VCPKG_DISABLE_METRICS=1 "$vcpkg_dir/vcpkg" install \
  --triplet "$SIM_VCPKG_TRIPLET" \
  --x-manifest-root="$root" \
  --x-install-root="$root/vcpkg_installed"
mkdir -p "$root/vcpkg_installed"
echo "$want" > "$stamp"
