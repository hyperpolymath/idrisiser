// SPDX-License-Identifier: PMPL-1.0-or-later
// Copyright (c) 2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
//
// Manifest parser for idrisiser.toml.

use anyhow::{Context, Result};
use serde::{Deserialize, Serialize};
use std::path::Path;

/// Top-level manifest.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Manifest {
    pub workload: WorkloadConfig,
    pub data: DataConfig,
    #[serde(default)]
    pub options: Options,
}

/// Workload description.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct WorkloadConfig {
    pub name: String,
    pub entry: String,
    #[serde(default)]
    pub strategy: String,
}

/// Data types flowing through the pipeline.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DataConfig {
    #[serde(rename = "input-type")]
    pub input_type: String,
    #[serde(rename = "output-type")]
    pub output_type: String,
}

/// Idris2-specific options.
#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct Options {
    #[serde(default)]
    pub flags: Vec<String>,
}

pub fn load_manifest(path: &str) -> Result<Manifest> {
    let content = std::fs::read_to_string(path)
        .with_context(|| format!("Failed to read manifest: {}", path))?;
    toml::from_str(&content)
        .with_context(|| format!("Failed to parse manifest: {}", path))
}

pub fn validate(manifest: &Manifest) -> Result<()> {
    if manifest.workload.name.is_empty() {
        anyhow::bail!("workload.name is required");
    }
    if manifest.workload.entry.is_empty() {
        anyhow::bail!("workload.entry is required");
    }
    Ok(())
}

pub fn init_manifest(path: &str) -> Result<()> {
    let manifest_path = Path::new(path).join("idrisiser.toml");
    if manifest_path.exists() {
        anyhow::bail!("idrisiser.toml already exists");
    }
    let template = r#"# idrisiser manifest
[workload]
name = "my-workload"
entry = "src/lib.rs::process"
strategy = "default"

[data]
input-type = "Vec<Item>"
output-type = "Vec<Result>"
"#;
    std::fs::write(&manifest_path, template)?;
    println!("Created {}", manifest_path.display());
    Ok(())
}

pub fn print_info(manifest: &Manifest) {
    println!("=== {} ===", manifest.workload.name);
    println!("Entry:  {}", manifest.workload.entry);
    println!("Input:  {}", manifest.data.input_type);
    println!("Output: {}", manifest.data.output_type);
}
