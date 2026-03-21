<!-- SPDX-License-Identifier: PMPL-1.0-or-later -->
<!-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk> -->
# TOPOLOGY.md — Idrisiser

## Purpose

Idrisiser is the **meta-prover** of the -iser family.  It takes interface
definitions (OpenAPI, C headers, `.proto`, type signatures) and generates
Idris2 dependent-type wrappers with formal proofs of correctness, compiled
to native code via Zig FFI.

## Module Map

```
idrisiser/
├── src/
│   ├── main.rs                    # CLI entry (clap): init, validate, generate, build, run, info
│   ├── lib.rs                     # Library API: load → validate → generate pipeline
│   ├── manifest/mod.rs            # idrisiser.toml parser (serde + toml)
│   ├── codegen/mod.rs             # Idris2 + Zig code generation orchestrator
│   ├── core/                      # [WIP] Proof obligation engine
│   ├── definitions/               # [WIP] Interface definition intermediate representation
│   ├── contracts/                 # [WIP] Contract extraction from parsed interfaces
│   ├── errors/                    # [WIP] Structured diagnostic types
│   ├── bridges/                   # [WIP] Adapters: OpenAPI, protobuf, C headers
│   ├── aspects/                   # Cross-cutting: integrity, observability, security
│   └── interface/
│       ├── abi/                   # Idris2 ABI — formal proof definitions
│       │   ├── Types.idr          #   InterfaceContract, ProofObligation, DependentWrapper
│       │   ├── Layout.idr         #   Memory layout proofs, struct alignment, C ABI compliance
│       │   └── Foreign.idr        #   FFI declarations with safety wrappers
│       ├── ffi/                   # Zig FFI — C-ABI bridge implementation
│       │   ├── build.zig          #   Build config: shared lib, static lib, tests, docs
│       │   ├── src/main.zig       #   FFI exports matching Foreign.idr declarations
│       │   └── test/              #   Integration tests verifying ABI↔FFI agreement
│       │       └── integration_test.zig
│       └── generated/             # Auto-generated C headers (output of proof compilation)
│           └── abi/               #   Generated .h files from Idris2 ABI definitions
├── verification/                  # Property-based and proof verification harnesses
├── examples/                      # End-to-end worked examples
├── container/                     # Stapeln container ecosystem files
├── docs/
│   ├── architecture/              # THREAT-MODEL, topology diagrams
│   ├── attribution/               # Citations, owners, maintainers
│   ├── theory/                    # Domain theory: dependent types, QTT, proof erasure
│   ├── practice/                  # User manuals, integration guides
│   ├── legal/                     # License exhibits
│   └── whitepapers/               # Research papers, design rationale
└── .machine_readable/
    ├── 6a2/                       # STATE, META, ECOSYSTEM, AGENTIC, NEUROSYM, PLAYBOOK
    ├── anchors/                   # ANCHOR.a2ml — canonical authority
    ├── policies/                  # Maintenance axes, checklist, dev approach
    ├── bot_directives/            # rhodibot, echidnabot, sustainabot, etc.
    ├── contractiles/              # k9, dust, lust, must, trust enforcement
    ├── ai/                        # AI.a2ml, PLACEHOLDERS.md
    └── integrations/              # Tool integration configs
```

## Data Flow

```
                    idrisiser.toml
                         │
                    ┌────▼────┐
                    │ Manifest │  Rust: parse + validate
                    │  Parser  │
                    └────┬────┘
                         │
                   ┌─────▼─────┐
                   │ Interface  │  Bridges: OpenAPI / .h / .proto / sigs
                   │   Parser   │
                   └─────┬─────┘
                         │  IR (contracts, types, invariants)
                   ┌─────▼─────┐
                   │   Proof    │  Derive proof obligations from contracts
                   │  Obligation│
                   │   Engine   │
                   └─────┬─────┘
                         │
              ┌──────────┼──────────┐
              ▼          ▼          ▼
         Types.idr  Layout.idr  Foreign.idr    Idris2 ABI generation
              │          │          │
              └──────────┼──────────┘
                         │
                   ┌─────▼─────┐
                   │  Idris2   │  Totality, termination, invariant proofs
                   │ Compiler  │  Elaborator reflection, QTT
                   └─────┬─────┘
                         │  Verified ABI
                   ┌─────▼─────┐
                   │  Zig FFI  │  C-ABI bridge: main.zig + build.zig
                   │ Generator │
                   └─────┬─────┘
                         │
                   ┌─────▼─────┐
                   │  Native   │  .so / .a / .dylib / .dll
                   │  Wrapper  │  Provably correct, zero proof overhead
                   └───────────┘
```

## Ecosystem Position

- **Above:** `iseriser` (meta-framework that scaffolds -iser repos)
- **Peers:** 28 other -iser repos (chapeliser, typedqliser, verisimiser, etc.)
- **Below:** `proven` (shared Idris2 verified library), `typell` (type theory engine)
- **Consumers:** Any -iser that needs formal verification routes through idrisiser
- **Unique role:** Only -iser that generates _proofs_, not just code

## Key Invariants

1. Generated Idris2 code must be **total** — no partial functions, no `sorry`, no `believe_me`
2. Proof obligations must be **complete** — every contract clause produces a proof term
3. Zig FFI must **exactly match** the Idris2 Foreign.idr declarations
4. Generated C headers must be **ABI-compatible** across Linux, macOS, Windows, WASM
5. The manifest is the **single source of truth** — all generation is deterministic
