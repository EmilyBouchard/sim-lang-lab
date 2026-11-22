# CLI11 (vendored)

Command-line parser used by the C++ apps.

- Upstream: https://github.com/CLIUtils/CLI11
- Version: 2.7.2
- File: `CLI11.hpp`, the standalone single-header release asset
  (https://github.com/CLIUtils/CLI11/releases/download/v2.7.2/CLI11.hpp)
- SHA-256 of `CLI11.hpp`: `ffa9a30da295c5858fb5f91f9f45771bab09471d7010a34c7c68c857a330dd76`
- License: BSD-3-Clause, see `LICENSE`

Why vendored and not from vcpkg: the vcpkg `cli11` port installs a *precompiled* library, which
does not link against MSVC AddressSanitizer builds (STL annotation mismatch, LNK2038). The single
header has no such problem, and keeping it here keeps this C++-only dependency out of the manifest
that all three languages share.

To upgrade: download the new `CLI11.hpp` and `LICENSE` for the release tag, update the version and
hash above, and rebuild. Do not edit `CLI11.hpp` by hand.
