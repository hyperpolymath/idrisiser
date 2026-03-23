// SPDX-License-Identifier: PMPL-1.0-or-later
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// Manifest parser for idrisiser.toml.
//
// The manifest describes interface definitions to be formally verified.
// Each interface produces an Idris2 module with dependent-type proofs,
// a Zig FFI bridge, and a compiled native wrapper.

use anyhow::{Context, Result, bail};
use serde::{Deserialize, Serialize};
use std::path::Path;

/// Top-level manifest structure, parsed from idrisiser.toml.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Manifest {
    /// The project being verified.
    pub project: ProjectConfig,
    /// Interface definitions to verify.
    pub interfaces: Vec<InterfaceConfig>,
    /// Proof generation options.
    #[serde(default)]
    pub proofs: ProofConfig,
    /// Idris2 compiler options.
    #[serde(default)]
    pub idris2: Idris2Config,

    // Keep backward compat with old manifests that use [workload] and [data]
    #[serde(default)]
    pub workload: Option<WorkloadCompat>,
    #[serde(default)]
    pub data: Option<DataCompat>,
}

// Backward-compatible types for old-format manifests
#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct WorkloadCompat {
    #[serde(default)]
    pub name: String,
    #[serde(default)]
    pub entry: String,
    #[serde(default)]
    pub strategy: String,
}
#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct DataCompat {
    #[serde(rename = "input-type", default)]
    pub input_type: String,
    #[serde(rename = "output-type", default)]
    pub output_type: String,
}

/// Project metadata.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ProjectConfig {
    /// Project name (used in generated module names).
    pub name: String,
    /// Output module prefix (e.g., "MyProject.Verified").
    #[serde(rename = "module-prefix", default)]
    pub module_prefix: Option<String>,
}

/// A single interface definition to verify.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct InterfaceConfig {
    /// Human-readable name for this interface.
    pub name: String,
    /// Path to the interface definition file.
    pub source: String,
    /// Interface format.
    pub format: InterfaceFormat,
    /// Which functions/endpoints to verify (empty = all).
    #[serde(default)]
    pub verify: Vec<String>,
    /// Custom preconditions to add.
    #[serde(default)]
    pub preconditions: Vec<String>,
    /// Custom postconditions to add.
    #[serde(default)]
    pub postconditions: Vec<String>,
    /// Custom invariants to maintain.
    #[serde(default)]
    pub invariants: Vec<String>,
}

/// Supported interface formats.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "kebab-case")]
pub enum InterfaceFormat {
    /// OpenAPI 3.x specification (YAML or JSON)
    Openapi,
    /// C header file (.h)
    CHeader,
    /// Protocol Buffers (.proto)
    Protobuf,
    /// Type signature file (custom format: name : Type)
    TypeSig,
}

impl InterfaceFormat {
    /// File extensions typically associated with this format.
    pub fn extensions(&self) -> &[&str] {
        match self {
            Self::Openapi => &["yaml", "yml", "json"],
            Self::CHeader => &["h", "hpp"],
            Self::Protobuf => &["proto"],
            Self::TypeSig => &["tsig", "idr"],
        }
    }
}

impl std::fmt::Display for InterfaceFormat {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::Openapi => write!(f, "openapi"),
            Self::CHeader => write!(f, "c-header"),
            Self::Protobuf => write!(f, "protobuf"),
            Self::TypeSig => write!(f, "type-sig"),
        }
    }
}

/// Configuration for proof generation.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ProofConfig {
    /// Require all functions to be total (default: true).
    #[serde(default = "default_true")]
    pub require_totality: bool,
    /// Generate serialisation round-trip proofs (default: true).
    #[serde(rename = "round-trip-proofs", default = "default_true")]
    pub round_trip_proofs: bool,
    /// Generate resource tracking via QTT (default: false).
    #[serde(rename = "qtt-tracking", default)]
    pub qtt_tracking: bool,
    /// Maximum proof search depth for auto-solver (default: 100).
    #[serde(rename = "search-depth", default = "default_search_depth")]
    pub search_depth: u32,
}

impl Default for ProofConfig {
    fn default() -> Self {
        Self {
            require_totality: true,
            round_trip_proofs: true,
            qtt_tracking: false,
            search_depth: 100,
        }
    }
}

/// Idris2 compiler configuration.
#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct Idris2Config {
    /// Extra compiler flags.
    #[serde(default)]
    pub flags: Vec<String>,
    /// Code generator backend: "chez" (default), "racket", "refc", "node".
    #[serde(default)]
    pub codegen: Option<String>,
    /// Package dependencies.
    #[serde(default)]
    pub packages: Vec<String>,
}

fn default_true() -> bool {
    true
}
fn default_search_depth() -> u32 {
    100
}

/// Load and parse an idrisiser.toml manifest from disk.
pub fn load_manifest(path: &str) -> Result<Manifest> {
    let content = std::fs::read_to_string(path)
        .with_context(|| format!("Failed to read manifest: {}", path))?;
    let manifest: Manifest =
        toml::from_str(&content).with_context(|| format!("Failed to parse manifest: {}", path))?;
    Ok(manifest)
}

/// Validate a parsed manifest.
pub fn validate(manifest: &Manifest) -> Result<()> {
    if manifest.project.name.is_empty() {
        bail!("project.name is required");
    }
    if manifest.interfaces.is_empty() {
        bail!("At least one [[interfaces]] entry is required");
    }
    for iface in &manifest.interfaces {
        if iface.name.is_empty() {
            bail!("interfaces.name is required for every interface");
        }
        if iface.source.is_empty() {
            bail!("interfaces.source is required for '{}'", iface.name);
        }
    }
    Ok(())
}

/// Create a starter idrisiser.toml in the given directory.
pub fn init_manifest(path: &str) -> Result<()> {
    let manifest_path = Path::new(path).join("idrisiser.toml");
    if manifest_path.exists() {
        bail!(
            "idrisiser.toml already exists at {}",
            manifest_path.display()
        );
    }

    let template = r#"# idrisiser manifest — describes interfaces to formally verify.
# See https://github.com/hyperpolymath/idrisiser for documentation.

[project]
name = "my-project"
module-prefix = "MyProject.Verified"

# Each [[interfaces]] entry is an interface definition to verify.
# idrisiser generates Idris2 dependent-type proofs for each.

[[interfaces]]
name = "user-api"
source = "openapi.yaml"         # path to interface definition
format = "openapi"              # openapi | c-header | protobuf | type-sig
verify = []                     # empty = verify all endpoints/functions
preconditions = []              # custom preconditions
postconditions = []             # custom postconditions
invariants = []                 # custom invariants

# [[interfaces]]
# name = "core-lib"
# source = "include/core.h"
# format = "c-header"
# verify = ["process_item", "reduce"]

[proofs]
require-totality = true         # all generated functions must be total
round-trip-proofs = true        # prove serialise/deserialise round-trips
qtt-tracking = false            # quantitative type theory for resource tracking
search-depth = 100              # max auto-proof search depth

# [idris2]
# flags = ["--total"]
# codegen = "chez"              # chez | racket | refc | node
# packages = ["contrib"]
"#;

    std::fs::write(&manifest_path, template)
        .with_context(|| format!("Failed to write {}", manifest_path.display()))?;
    println!("Created {}", manifest_path.display());
    println!("Edit the manifest to describe your interfaces, then run: idrisiser generate");
    Ok(())
}

/// Print information about a parsed manifest.
pub fn print_info(manifest: &Manifest) {
    println!("=== idrisiser: {} ===", manifest.project.name);
    if let Some(ref prefix) = manifest.project.module_prefix {
        println!("Module prefix: {}", prefix);
    }
    println!();
    println!("Interfaces ({}):", manifest.interfaces.len());
    for iface in &manifest.interfaces {
        let verify_count = if iface.verify.is_empty() {
            "all".to_string()
        } else {
            format!("{}", iface.verify.len())
        };
        println!(
            "  {} — {} ({}, verify: {})",
            iface.name, iface.source, iface.format, verify_count
        );
        if !iface.preconditions.is_empty() {
            println!("    Preconditions:  {}", iface.preconditions.len());
        }
        if !iface.postconditions.is_empty() {
            println!("    Postconditions: {}", iface.postconditions.len());
        }
        if !iface.invariants.is_empty() {
            println!("    Invariants:     {}", iface.invariants.len());
        }
    }
    println!();
    println!("Proofs:");
    println!("  Totality:    {}", manifest.proofs.require_totality);
    println!("  Round-trip:  {}", manifest.proofs.round_trip_proofs);
    println!("  QTT:         {}", manifest.proofs.qtt_tracking);
    println!("  Search depth: {}", manifest.proofs.search_depth);
}
