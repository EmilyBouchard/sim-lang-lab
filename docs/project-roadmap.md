# Project Roadmap — Incremental Difficulty, C++ / C# / Haskell

Ordered easiest → hardest. Every project is implemented in all three languages before
moving to the next tier, so the cross-language comparison stays consistent at each
step. Each tier lists a goal, concrete objectives, and acceptance criteria.

---

## Tier 0 — Foundations

### 0.1 — Window + Clear Color
**Goal:** Prove the SDL3 toolchain works end-to-end in all three languages.
**Objectives:**
- Open a window, poll events, clear to a color, present, clean shutdown on close/Esc.
**Acceptance criteria:**
- Runs on all three languages via `build.sh <lang> apps/hello-window` (`build.ps1` on Windows).
- Closes cleanly with no leaked resources (sanitizer/valgrind for C++, no unhandled
  exceptions for C#, no resource-leak warnings for Haskell). C++ leak detection is
  Linux-only: MSVC's AddressSanitizer does not detect leaks.
- CI builds and smoke-runs it headless on every pull request and every push to `main`
  (`main` only accepts changes through a PR whose checks pass; see `docs/architecture/ci.md`).

### 0.2 — Input & Primitive Drawing
**Goal:** Exercise input handling and basic 2D drawing primitives.
**Objectives:**
- Draw shapes (rect, line, circle); move a shape with keyboard/mouse.
**Acceptance criteria:**
- Keyboard and mouse both drive on-screen state.
- Frame time is measured and logged (establishes timing/profiling habit early).

### 0.3 — Math Library v1 (Vec2/Vec3, float+double)
**Goal:** First version of the hand-rolled math library, tested in isolation before
any app depends on it.
**Objectives:**
- `Vec2<T>`, `Vec3<T>` with add/sub/scale/dot/length/normalize; both `float` and
  `double` instantiations.
**Acceptance criteria:**
- Unit tests cover each op, including edge cases (zero-vector normalize, precision
  comparison between float/double on identical inputs).
- No app code yet — pure library milestone.

---

## Tier 1 — Real-Time Clock (digital + analog)

**Goal:** First real app — combines math library, drawing, and wall-clock time, plus
a first layout problem (two display modes in one window).
**Objectives:**
- Digital display: HH:MM:SS from system time.
- Analog display: clock face with hour/minute/second hands, positioned via `Vec2`
  rotation from the math library.
- Toggle or split-screen between the two modes.
**Acceptance criteria:**
- Hand positions computed via the math library's rotation, not hardcoded per-frame
  angles — first real usage of the math lib in an app.
- Time source is injectable/fake-able for unit testing hand-angle calculations
  independent of real wall-clock.
- Correct across 12/24-hour and day-boundary edge cases (unit-testable without
  waiting a day).
- Visual: smooth movement, no jitter or drift over a multi-minute run.

---

## Tier 2 — Bouncing Ball Simulation

**Goal:** First physics: numerical integration, collision response, and the
simulation-loop pattern reused all the way to Barnes-Hut/FMM.
**Objectives:**
- Single ball under gravity, bouncing off floor/walls with a restitution
  coefficient.
- Fixed-timestep integration (semi-implicit Euler to start).
**Acceptance criteria:**
- With restitution < 1, total mechanical energy decreases monotonically over N
  bounces — asserted as a test.
- Simulation decoupled from rendering (fixed physics timestep vs. variable render
  rate) — required pattern for later N-body work.
- Deterministic given identical initial conditions and timestep (needed for later
  cross-language behavioral comparison).

### 2.5 — Multi-Ball / Simple Collisions
**Goal:** Bridge from one body to many, and from wall-collision to body-body
collision, without yet needing spatial partitioning.
**Objectives:**
- N balls, brute-force O(N²) pairwise collision detection, elastic or inelastic
  response.
**Acceptance criteria:**
- O(N²) collision detection explicitly implemented and benchmarked — this is the
  baseline later compared against spatial-partitioning approaches.
- Automated conservation checks (momentum; energy if elastic).

---

## Tier 3 — Simple UI Framework

**Goal:** Build the minimal UI toolkit needed for later projects (file browser
needs lists/labels/buttons; simulations want parameter panels, play/pause,
sliders).
**Objectives:**
- Widgets: label, button, slider, panel/layout container. Immediate-mode is the
  pragmatic choice (simpler state management, faster to build across three
  languages).
**Acceptance criteria:**
- A demo app exercises every widget type via the `sdl-platform` input wrapper.
- Widget hit-testing and layout unit-tested independent of rendering (click at
  (x,y) → correct widget receives the event).
- Treated as its own versioned, tested library milestone (same rigor as `math`).

---

## Tier 3.5 — Data Pipeline Projects

Two sibling CLI tools per language, both producing SQLite as their output
artifact. This is a fourth shared "domain" alongside math/platform/UI, and it
exercises the `data` library.

**Data policy: reference epochs, not live-by-default.**
- A small, fixed set of reference epochs (e.g. `2000-01-01`, `2026-01-01`, plus one
  longer-baseline epoch) are fetched once, manually, and the resulting `.db`
  files are committed to `shared/test-data/jpl-references/`.
- All downstream projects (Tier 5's Kepler test, Tier 9's validation) read only
  these committed files. CI never touches the network.
- Live fetching remains available as a deliberate, manual maintenance action
  (`refresh-references`), run occasionally by you, not invoked by CI or by any
  other project's build.

### Project A — JPL Snapshot Tool
**Goal:** Fetch real solar-system body data (JPL Horizons/SBDB) and persist it as
a reusable SQLite snapshot.
**Objectives:**
- `fetch --epoch=... --bodies=... --out=snapshot.db`: query JPL, parse response,
  write SQLite with a defined schema (position, velocity, mass, epoch, body
  name/id).
- `refresh-references`: re-fetch all committed reference epochs for maintenance,
  reporting a diff against currently-committed files.
**Acceptance criteria:**
- Schema defined once in `shared/data-schema/bodies.sql`, used identically by all
  three languages' writers.
- Parsing logic is unit-testable against a recorded fixture response committed to
  `shared/test-data/` — no live network access required in CI.
- Produced SQLite files are validated for schema correctness (table structure +
  row counts), not just "did it not crash."
- Reference epochs, body sets, and exact JPL query parameters are documented in
  `shared/test-data/jpl-references/README.md`, so any reference file can be
  regenerated deterministically.
- CI only exercises the parser against fixtures and validates committed reference
  files' schema — never a live call.
- Cross-language diff test: same query in C++/C#/Haskell produces schema-identical
  output with matching rows (floating-point tolerance allowed).

### Project B — Artificial Dataset Generator
**Goal:** Parameterized random N-body dataset generator for stress testing,
outputting the same SQLite schema as Project A.
**Objectives:**
- CLI knobs: N (particle count), spatial distribution (uniform cube/sphere,
  Plummer sphere, disk, clustered), mass distribution (uniform, power-law),
  velocity initialization (zero, random, virial-equilibrium-ish), and a seed for
  reproducibility.
**Acceptance criteria:**
- Same seed + parameters → statistically identical output within a language, and
  matching summary statistics (mean, variance, bounding box) across languages
  (bit-identical RNG streams across languages isn't realistic).
- Each distribution option has a unit test asserting basic statistical sanity
  (e.g. Plummer sphere density falloff, uniform cube stays within bounds).
- Can generate at least the Tier 7 stress-test target N (100k+) within a
  reasonable time budget; generation time itself is logged as a mini-benchmark
  (shouldn't dominate simulation benchmark wall-clock).
- Schema-identical to Project A's output — a single "load initial conditions from
  SQLite" function in simulation code works unmodified regardless of which tool
  produced the file.

---

## Tier 4 — 3D File Browser (Jurassic Park UI)

**Goal:** First 3D rendering, first camera/projection math, first real use of
`Mat4`/`Quaternion`, first "spatial layout of arbitrary data" problem.
**Objectives:**
- Recurse a real directory tree; lay out files/folders as 3D objects.
- Camera: perspective projection, basic fly/orbit controls using `Mat4`/`Vec3`
  (first real stress test of `Mat4` correctness).
- Selecting/entering a folder animates the camera or transitions view.
**Acceptance criteria:**
- Math library gains `Mat4` (translate/rotate/scale composition, perspective +
  view matrix) and `Quaternion` (camera orientation) — both float/double, unit
  tested against known reference transforms.
- Handles real, arbitrarily deep/wide directory trees without breaking (defined
  max-depth/width fallback rather than crashing).
- Frame rate stays above a defined target (e.g. 60fps) for a directory tree of a
  defined size (e.g. 10k files) — first "does the render path scale" benchmark.
- UI panel (from Tier 3) shows current path/breadcrumb using the project's own UI
  kit.

### 4.5 — Orbit Camera / Solar System Toy
**Goal:** Bridge from static 3D scene to *moving* 3D bodies under simple rules —
precursor to real N-body work, and first consumer of Tier 3.5's JPL data.
**Objectives:**
- A handful of bodies (sun + a few planets) on fixed circular/elliptical orbits
  (kinematic, not force-simulated) rendered in 3D, loaded from Tier 3.5's
  committed reference snapshot.
**Acceptance criteria:**
- Orbital position computed per-frame via the math library (rotation via
  quaternion or matrix, not ad hoc trig in render code).
- Confirms the "load bodies from SQLite" interface works end-to-end from a real
  consumer before Tier 5 depends on it for physics.

---

## Tier 5 — Brute-Force N-Body Simulation (2D)

**Goal:** The physics core at naive O(N²) complexity — direct predecessor to
Barnes-Hut/FMM and the baseline they're benchmarked against.
**Objectives:**
- Gravitational force calculation between all pairs, integrated over time
  (semi-implicit Euler; Velocity Verlet or RK4 as a stretch goal).
- Initial conditions loaded from Tier 3.5 outputs: the committed JPL reference
  snapshot, and the artificial dataset generator.
**Acceptance criteria:**
- Two-body case loaded from the committed JPL reference reproduces a known
  analytical result (Kepler orbit period/shape) within tolerance — this becomes
  the standard regression test reused unchanged through Tier 9.
- Performance benchmarked and recorded in `shared/bench-schema` format at
  multiple N (100, 1k, 10k) — establishes the O(N²) curve later tiers beat.
- Numerical stability documented: does the simulation blow up over long runs, and
  at what N/timestep combination.

### 5.5 — Brute-Force N-Body in 3D
**Goal:** Extend the same physics to 3D before adding spatial-partitioning
complexity — isolates "went to 3D" from "went to Barnes-Hut."
**Objectives:**
- Same force/integration logic over `Vec3`; render using the Tier 4 3D pipeline.
**Acceptance criteria:**
- Same Kepler regression test, now in 3D (non-planar orbit).
- Reuses Tier 4's camera/rendering rather than rebuilding it — validates the 3D
  rendering path is generic enough for reuse.

---

## Tier 6 — Barnes-Hut Simulation, 2D

**Goal:** First spatial data structure (quadtree), first approximation
algorithm, first real algorithmic complexity win to measure.
**Objectives:**
- Quadtree construction from particle positions each frame.
- Center-of-mass approximation with configurable θ (opening angle).
**Acceptance criteria:**
- Kepler regression test still passes (θ→0 converges to brute-force result within
  tolerance).
- Accuracy-vs-θ tradeoff measured and documented (force error vs. brute-force
  baseline, several θ values).
- Performance benchmarked vs. Tier 5's baseline at matching N — must show the
  expected O(N log N) curve, recorded in the same bench schema.
- Quadtree logic has isolated unit tests independent of physics (fixed points →
  correct tree shape and center-of-mass values).

---

## Tier 7 — Barnes-Hut Simulation, 3D (Octree)

**Goal:** Extend Barnes-Hut to 3D — an engineering exercise with real added
complexity (8-way subdivision, more edge cases).
**Objectives:**
- Octree replaces quadtree; same θ-approximation approach.
**Acceptance criteria:**
- Same regression + accuracy-vs-θ + performance-vs-baseline tests as Tier 6, now
  in 3D.
- Runs the Tier 3.5 artificial-dataset generator's output at a defined target N
  (e.g. 100k+ bodies), recording performance across all three languages — a
  headline comparison result.

---

## Tier 8 — Fast Multipole Method, 2D

**Goal:** Significant jump in complexity — multipole/local expansions and the
up/down-tree pass structure differ substantially from Barnes-Hut.
**Objectives:**
- Multipole expansion of far-field particle groups, translation operators (M2M,
  M2L, L2L), direct evaluation for near-field.
**Acceptance criteria:**
- Same Kepler regression test.
- Accuracy vs. expansion order (p) measured and documented, analogous to θ for
  Barnes-Hut.
- Performance vs. Barnes-Hut and brute-force baselines at matching N, showing
  FMM's O(N) advantage at sufficiently large N — document the crossover point
  honestly (FMM's higher constant factor may lose at smaller N).
- Isolated unit tests per operator (M2M, M2L, L2L, direct) with hand-computable
  small cases, not just end-to-end simulation tests.

---

## Tier 9 — Fast Multipole Method, 3D — Capstone

**Goal:** Full 3D FMM, validated against real JPL data and stress-tested against
the artificial dataset at scale, across all three languages.
**Objectives:**
- 3D multipole expansions (typically spherical-harmonics-based), full FMM tree
  pass.
- Validation against Tier 3.5's committed JPL reference data; stress test against
  Tier 3.5's generator output.
**Acceptance criteria:**
- Correctness validated against real JPL trajectories over a defined time window
  (simulated planetary motion tracks published ephemeris data within acceptable
  error over N simulated days/years).
- Full four-way benchmark comparison (brute-force, Barnes-Hut, FMM, in 2D and 3D)
  across all three languages at matching N values, published via the
  `shared/bench-schema` pipeline built in Tier 5.
- Documented crossover points: at what N does each algorithm become the best
  choice, and whether that crossover differs meaningfully by language (e.g. GC
  pause behavior shifting the crossover in C#/Haskell vs. C++).
- Stress test at the largest N the generator can produce within a reasonable
  wall-clock budget, per language — framed as one data point among several
  (correctness, dev velocity, code clarity are also worth documenting).

---

## Summary table

| Tier | Project | New skill introduced |
|---|---|---|
| 0 | Window / Input / Math v1 | Toolchain, SDL basics, math lib foundation |
| 1 | Real-time clock | Wall-clock integration, vector rotation |
| 2 | Bouncing ball | Fixed-timestep integration, collision response |
| 2.5 | Multi-ball collisions | O(N²) baseline pattern, conservation testing |
| 3 | Simple UI framework | Widget/layout system, input dispatch |
| 3.5 | JPL snapshot tool + dataset generator | SQLite writer, external API integration, schema design, reproducible RNG, reference-epoch policy |
| 4 | 3D file browser | Mat4/Quaternion, camera/projection, 3D rendering |
| 4.5 | Orbit camera / solar system toy | First consumer of JPL data, kinematic orbits |
| 5 | Brute-force N-body, 2D | Gravitational N-body, Kepler regression test, bench pipeline |
| 5.5 | Brute-force N-body, 3D | 3D physics reusing 3D render path |
| 6 | Barnes-Hut, 2D | Quadtree, approximation algorithms, accuracy/perf tradeoffs |
| 7 | Barnes-Hut, 3D | Octree, large-N stress testing |
| 8 | FMM, 2D | Multipole expansions, translation operators |
| 9 | FMM, 3D (capstone) | Full FMM, JPL validation, final cross-language report |
