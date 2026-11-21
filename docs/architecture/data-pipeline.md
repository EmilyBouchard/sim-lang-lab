# Data Pipeline Conventions

- **Schema contract:** `shared/data-schema/bodies.sql` defines the SQLite schema (position, velocity, mass, epoch, body name/id) used identically by the JPL snapshot tool and the dataset generator in all three languages. Any simulation project's "load bodies from SQLite" function works unmodified regardless of which tool produced the file.
- **Reference epochs, not live-by-default:** a small, fixed set of reference epochs (e.g. `2000-01-01`, `2026-01-01`, plus one longer-baseline epoch) are fetched once, manually, via each language's `jpl-snapshot` tool, and the resulting `.db` files are committed to `shared/test-data/jpl-references/`. All downstream projects read only these committed files — CI never hits the network.
- **Live fetch as maintenance, not a dependency:** the JPL tool's live-fetch/`refresh-references` capability remains available but is invoked manually and occasionally, never by CI or by another project's build.
- **Documentation:** `shared/test-data/jpl-references/README.md` records the exact epoch, body set, and JPL query parameters used for each committed reference file, so any of them can be regenerated deterministically.
