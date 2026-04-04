# TEST-NEEDS.md — idrisiser

## CRG Grade: C — ACHIEVED 2026-04-04

## Current Test State

| Category | Count | Notes |
|----------|-------|-------|
| Integration tests (Rust) | 3 | `tests/integration_test.rs` |
| Unit tests (Rust, `#[test]`) | 31 | Across `src/` modules |
| Fuzz tests | 0 | `tests/fuzz/` directory present but empty |

## What's Covered

- [x] `manifest::init_manifest` — creates `idrisiser.toml` in a temp dir
- [x] `manifest::load_manifest` + `validate` — roundtrip against example manifest
- [x] `validate` rejects empty project name
- [x] 31 unit test annotations across source modules (codegen, ABI, etc.)

## CI Gate

```bash
cargo test
```

## Known Failures / Limitations

- `tests/fuzz/` exists but contains no fuzz targets
- Integration tests depend on `examples/user-api/idrisiser.toml` — if that
  example is removed, tests break
- No property-based tests

## Still Missing (for CRG B+)

- [ ] Fuzz targets for manifest parsing
- [ ] Tests for the Idris2 codegen output (verify generated `.idr` files)
- [ ] CI job independent of parent repo
- [ ] 6+ diverse external targets (CRG B requirement)
