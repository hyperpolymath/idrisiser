// SPDX-License-Identifier: PMPL-1.0-or-later
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// ABI module — Rust-side types mirroring the Idris2 ABI formal definitions.
//
// The Idris2 proofs in src/interface/abi/*.idr guarantee correctness at compile time.
// This Rust module provides runtime representations for:
//   - Interface formats and contracts
//   - Proof obligations and their discharge status
//   - Verification results

use serde::{Deserialize, Serialize};

/// FFI result codes. Must match Idrisiser.ABI.Types.Result.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[repr(i32)]
pub enum FfiResult {
    Ok = 0,
    Error = 1,
    InvalidParam = 2,
    OutOfMemory = 3,
    NullPointer = 4,
    ProofFailure = 5,
}

/// Supported interface formats.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum InterfaceFormat {
    OpenApi,
    CHeader,
    Protobuf,
    TypeSig,
}

/// A contract clause (precondition, postcondition, or invariant).
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ContractClause {
    /// The kind of clause.
    pub kind: ClauseKind,
    /// Human-readable description of the clause.
    pub description: String,
    /// Whether this clause has been proven (discharged).
    pub discharged: bool,
}

/// Kind of contract clause.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum ClauseKind {
    Precondition,
    Postcondition,
    Invariant,
}

/// A proof obligation generated from a contract.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ProofObligation {
    /// Which function this obligation belongs to.
    pub function_name: String,
    /// The kind of proof required.
    pub kind: ProofKind,
    /// The Idris2 type signature of the proof.
    pub type_signature: String,
    /// Whether the proof has been discharged (verified).
    pub discharged: bool,
}

/// Kinds of proofs that idrisiser generates.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum ProofKind {
    /// Function covers all inputs and terminates.
    Totality,
    /// Recursive operations have a decreasing measure.
    Termination,
    /// A state invariant holds before and after.
    Invariant,
    /// Input/output types match the declared schema.
    TypeSafety,
    /// Linear/affine resources are properly tracked (QTT).
    Resource,
    /// Serialise then deserialise yields the original value.
    RoundTrip,
}

/// Summary of a verification run.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct VerificationSummary {
    /// Number of interfaces verified.
    pub interfaces: usize,
    /// Number of functions across all interfaces.
    pub functions: usize,
    /// Total proof obligations generated.
    pub total_obligations: usize,
    /// Obligations successfully discharged.
    pub discharged: usize,
    /// Obligations remaining (not yet proven).
    pub remaining: usize,
    /// Whether all obligations are discharged.
    pub all_proven: bool,
}

impl VerificationSummary {
    /// Create a summary from a list of proof obligations.
    pub fn from_obligations(
        interfaces: usize,
        functions: usize,
        obligations: &[ProofObligation],
    ) -> Self {
        let total = obligations.len();
        let discharged = obligations.iter().filter(|o| o.discharged).count();
        Self {
            interfaces,
            functions,
            total_obligations: total,
            discharged,
            remaining: total - discharged,
            all_proven: discharged == total,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn verification_summary_all_proven() {
        let obligations = vec![
            ProofObligation {
                function_name: "foo".into(),
                kind: ProofKind::Totality,
                type_signature: "foo_total : FooTotal".into(),
                discharged: true,
            },
            ProofObligation {
                function_name: "foo".into(),
                kind: ProofKind::RoundTrip,
                type_signature: "foo_rt : FooRoundTrip".into(),
                discharged: true,
            },
        ];
        let summary = VerificationSummary::from_obligations(1, 1, &obligations);
        assert!(summary.all_proven);
        assert_eq!(summary.remaining, 0);
    }

    #[test]
    fn verification_summary_partial() {
        let obligations = vec![
            ProofObligation {
                function_name: "bar".into(),
                kind: ProofKind::Totality,
                type_signature: "".into(),
                discharged: true,
            },
            ProofObligation {
                function_name: "bar".into(),
                kind: ProofKind::Invariant,
                type_signature: "".into(),
                discharged: false,
            },
        ];
        let summary = VerificationSummary::from_obligations(1, 1, &obligations);
        assert!(!summary.all_proven);
        assert_eq!(summary.remaining, 1);
    }
}
