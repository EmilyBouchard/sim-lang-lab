#!/usr/bin/env bash
# Source this to point every language at the vcpkg-installed SDL3:
#   source scripts/env.sh
# Exports SIM_VCPKG_TRIPLET, SIM_VCPKG_PREFIX and PKG_CONFIG_LIBDIR.
# (Windows: use scripts/env.ps1 instead.)
_sim_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

case "$(uname -s)-$(uname -m)" in
  Linux-x86_64) SIM_VCPKG_TRIPLET=x64-linux-dynamic ;;
  *) echo "scripts/env.sh: unsupported platform $(uname -s)-$(uname -m) (Windows: use env.ps1)" >&2
     return 1 2>/dev/null || exit 1 ;;
esac

export SIM_VCPKG_TRIPLET
export SIM_VCPKG_PREFIX="$_sim_root/vcpkg_installed/$SIM_VCPKG_TRIPLET"
# LIBDIR (not PATH) replaces the default search path, so the system sdl3.pc can never be used.
export PKG_CONFIG_LIBDIR="$SIM_VCPKG_PREFIX/lib/pkgconfig:$SIM_VCPKG_PREFIX/share/pkgconfig"
unset _sim_root
