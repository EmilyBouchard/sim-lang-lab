# Dependencies (SDL3 via vcpkg)

All three languages use **one pinned SDL3 build**, installed by vcpkg. There is no
system-SDL fallback: a build that cannot find the vcpkg install fails with a clear message.

## Pieces

| File | Role |
|---|---|
| `vendor/vcpkg` | vcpkg itself, as a git submodule. Its commit is the version registry snapshot. |
| `vcpkg.json` | Manifest: `sdl3` and `pkgconf`. `builtin-baseline` is the `vendor/vcpkg` commit, and `overrides` pins `sdl3` (currently 3.4.20). |
| `scripts/setup-deps.sh` / `.ps1` | Init the submodule, bootstrap vcpkg, run `vcpkg install` into `vcpkg_installed/`. Idempotent, and re-runs when `vcpkg.json` or the vcpkg commit changes. |
| `scripts/env.sh` / `.ps1` | Export `SIM_VCPKG_PREFIX` (the install prefix), `SIM_VCPKG_TRIPLET` and `PKG_CONFIG_LIBDIR`. |
| `vcpkg_installed/` | Install output. Git-ignored. |

`build.sh` and `build.ps1` run setup and env automatically. To build a language directory
directly (`cd cpp && cmake ...`), run `scripts/setup-deps.sh` once and `source scripts/env.sh` first.

## Triplets

`x64-linux-dynamic` and `x64-windows`. Both are **dynamic**. The default `x64-linux` triplet is
static, which would bake SDL into each binary and leave C# with nothing to load.

## How each language finds SDL3

- **C++:** `find_package(SDL3 3.4 CONFIG PATHS $ENV{SIM_VCPKG_PREFIX} NO_DEFAULT_PATH)` in
  `cpp/CMakeLists.txt`. CMake records the library directory as the binary's RPATH.
- **C#:** `SDL3-CS` ships no native library. `HelloWindow.csproj` copies `libSDL3.so` (Linux) or
  `SDL3.dll` (Windows) from the vcpkg prefix into the output folder, and .NET loads it from there.
- **Haskell (`sdl3-hs`):** its `pkgconfig-depends: sdl3` is resolved with `PKG_CONFIG_LIBDIR`
  pointing at the vcpkg `.pc` files, which also supply the rpath.

## Upgrading SDL3

1. Update the `vendor/vcpkg` submodule to a commit whose `versions/s-/sdl3.json` has the new version.
2. Set `builtin-baseline` in `vcpkg.json` to that commit and update the `sdl3` override.
3. Commit the submodule pointer and manifest together.

## System packages (Linux)

vcpkg builds SDL3 from source and needs system dev packages (X11, Wayland, ibus, ALSA, and
`autoconf`, `autoconf-archive`, `automake`, `libtool`, `zip`). CI installs them in
`.github/actions/setup-deps/action.yml`. On Arch: `zip wayland-protocols autoconf-archive`
(plus `autoconf automake libtool`) were the ones missing on the first setup.

## Trade-off

The shared manifest and install tree couple the three language directories to the repo root.
The benefit is that every language is guaranteed the same SDL build, which keeps the comparison fair.
