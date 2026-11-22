# Open Items — Architecture

- [x] Confirm exact `sdl3-hs` version/commit targeting SDL 3.4 and pin it explicitly. Pinned as a git submodule at `haskell/vendor/sdl3-hs` (commit `d4a6b6e`); it is not on Hackage. It requires SDL `>=3.3.0` via `pkgconfig-depends`, and CI checks out submodules.
- [x] Resolve SDL3 portably for all languages: pinned via vcpkg (`vendor/vcpkg`, `vcpkg.json`). See `dependencies.md`. Verified on Linux and Windows (local builds only, no Windows CI because of the runner cost).
- [ ] Verify `sdl3-hs` API coverage against the SDL3 subsystems actually needed (windowing, input, rendering — GPU API if required later).
- [ ] Decide on UI framework scope (confirmed immediate-mode) before scaffolding `libs/ui`.
- [ ] Scaffold actual `CMakeLists.txt` / `.csproj` / `.cabal` files per the structure above. (`hello-window` is scaffolded in all three languages; the libraries are not.)
- [ ] Define the full benchmark operation set (add, dot, cross, mat4 multiply, quaternion slerp, batch update) as a shared spec so all three languages implement the same suite.
- [ ] Confirm exact reference epochs, body sets, and JPL query parameters before first commit of `shared/test-data/jpl-references/`.
- [ ] Define the artificial dataset's default parameter presets (e.g. a "standard stress test" preset) so later benchmark invocations are standardized and reproducible across languages.
