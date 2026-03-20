# idrisiser — Project Instructions

## Overview

Generate proven-correct wrappers using Idris2 dependent types

**Status:** scaffold
**Priority in -iser family:** —
**Part of:** https://github.com/hyperpolymath/iseriser (-iser ecosystem)

## Architecture

All -iser projects follow the same architecture:
- **Manifest** (`idrisiser.toml`) — user describes WHAT they want
- **Idris2 ABI** (`src/abi/` or `src/interface/abi/`) — formal proofs of interface correctness
- **Zig FFI** (`ffi/zig/` or `src/interface/ffi/`) — C-ABI bridge to target language
- **Codegen** (`src/codegen/`) — generates target language wrapper code
- **Rust CLI** (`src/main.rs`) — orchestrates everything

## Build & Test

```bash
cargo build --release
cargo test
```

## Key Design Decisions

- Follows hyperpolymath ABI-FFI standard (Idris2 ABI, Zig FFI)
- PMPL-1.0-or-later license
- RSR (Rhodium Standard Repository) template
- Author: Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>

## Integration Points

- **iseriser**: Meta-framework that can generate new -iser scaffolding
- **typedqliser**: #1 priority — formal type safety for query languages
- **chapeliser**: #2 priority — distributed computing acceleration
- **verisimiser**: #3 priority — database octad augmentation
- **squeakwell**: Database recovery via cross-modal constraint propagation
