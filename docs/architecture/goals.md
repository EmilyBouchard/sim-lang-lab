# Design Goals

1. **Fair language comparison** — each language implementation is isolated and self-contained; no cross-language dependencies leak into the comparison.
2. **Code reuse within a language** — shared libraries (math, platform, UI, data) are referenced across multiple executable projects in that language.
3. **Own math primitives** — vectors, matrices, quaternions are hand-rolled per language (not sourced from libraries), specifically so language performance/ergonomics are what's being compared, not library quality.
4. **Float/double switchable math** — every math type can be instantiated at either precision so that precision and language are independent, comparable axes.
5. **Consistent testing and CI** — unit + integration tests in every project and library, with per-language CI workflows.
6. **Unified orchestration** — one top-level script can build/test everything, one language, or a single project.
7. **Cross-language benchmarking** — a common result schema lets benchmark output from all three languages be compared side by side.
