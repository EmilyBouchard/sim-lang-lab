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
  `cpp/CMakeLists.txt`. On Linux CMake records the library directory as the binary's RPATH. On Windows there is no RPATH, so `sim_copy_runtime_dlls()` (in `cpp/CMakeLists.txt`) copies `SDL3.dll`, and the ASan runtime for sanitizer builds, next to the exe after each build.
- **C#:** `SDL3-CS` ships no native library. `HelloWindow.csproj` copies `libSDL3.so` (Linux) or
  `SDL3.dll` (Windows) from the vcpkg prefix into the output folder, and .NET loads it from there.
- **Haskell (`sdl3-hs`):** its `pkgconfig-depends: sdl3` is resolved with `PKG_CONFIG_LIBDIR`
  pointing at the vcpkg `.pc` files, which also supply the rpath on Linux (on Windows `build.ps1` copies `SDL3.dll` next to each Haskell exe after `cabal build`). Cabal looks for `pkg-config`, but vcpkg's port only ships `pkgconf.exe`, so `scripts/env.ps1` copies it to `pkg-config.exe`.

## Command-line parsing

Argument parsing is not what this project is about, so each app uses its language's standard
library. Each gives `--help` and a clear message for a bad option or value.

| Language | Library | Comes from |
|---|---|---|
| C++ | [CLI11](https://github.com/CLIUtils/CLI11) | Vendored single header, `cpp/third_party/CLI11/` (version, source and hash in its README) |
| C# | `System.CommandLine` | `PackageReference` in the `.csproj` |
| Haskell | `optparse-applicative` | `build-depends` in `sim-lang-lab.cabal` |

Contract for `hello-window` (the same in all three): `--frames N` takes a non-negative integer and
exits after N frames. A bad or missing value, or an unknown option, prints a message that names the
offending text, followed by the usage (C++ and C# print the whole help, Haskell the usage line and
description), and exits non-zero **before** SDL is initialised. `--help` prints usage and exits 0.
All three read the value as a 64-bit integer.
The exit code on error is whatever the library chooses (CLI11 uses its own codes, the other two use
1), so tests check for a non-zero exit or the message, not a specific number. One known difference:
CLI11 also accepts hex, octal and binary prefixes (`--frames 0x10`); the C# and Haskell parsers
accept decimal digits only.

`scripts/check_hello_window_cli.py` checks this contract against any of the three apps: the exit
code, that the message names the bad value, that the usage is printed, and that the app does not
hang. ctest runs it for C++ (`hello-window-cli`), and `build.sh --test` / `build.ps1 -Test` run it
for C# and Haskell. It needs Python 3 and only the standard library.

Notes:
- CLI11 is vendored as its single header instead of coming from vcpkg. The vcpkg port builds a
  *precompiled* library, which does not link against MSVC AddressSanitizer builds (STL annotation
  mismatch), and a C++-only dependency does not belong in the manifest all three languages share.
  `cpp/third_party/.clang-format` turns the formatter off for it.
- `sdl3-hs` exports a record field named `info`, which clashes with optparse-applicative's `info`,
  so `Main.hs` imports `SDL3 hiding (info)`.
- CI runs `cabal update` before building, because `optparse-applicative` is not a GHC boot package.

## Upgrading SDL3

1. Update the `vendor/vcpkg` submodule to a commit whose `versions/s-/sdl3.json` has the new version.
2. Set `builtin-baseline` in `vcpkg.json` to that commit and update the `sdl3` override.
3. Commit the submodule pointer and manifest together. `scripts/setup-deps.*` fail with a clear
   message if `builtin-baseline` and the `vendor/vcpkg` commit disagree.

## Windows prerequisites

`scripts/vsenv.ps1` loads the MSVC x64 environment (found with `vswhere`) for the C++ step only;
`build.ps1` restores the environment afterwards because `vcvars64.bat` sets `Platform=x64`, which
would change MSBuild's output paths for C#. Install the "Desktop development with C++" workload;
vcpkg builds SDL3 with it. See the README for the full list.

## System packages (Linux)

vcpkg builds SDL3 from source and needs system dev packages (X11, Wayland, ibus, ALSA, and
`autoconf`, `autoconf-archive`, `automake`, `libtool`, `zip`). CI installs them in
`.github/actions/setup-deps/action.yml`. On Arch: `zip wayland-protocols autoconf-archive`
(plus `autoconf automake libtool`) were the ones missing on the first setup.

## Trade-off

The shared manifest and install tree couple the three language directories to the repo root.
The benefit is that every language is guaranteed the same SDL build, which keeps the comparison fair.
