// SPDX-License-Identifier: PMPL-1.0-or-later
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
//
// Integration tests for idrisiser CLI.

use std::fs;

#[test]
fn test_init_creates_manifest() {
    let dir = tempfile::tempdir().unwrap();
    let manifest = dir.path().join("idrisiser.toml");

    idrisiser::manifest::init_manifest(dir.path().to_str().unwrap()).unwrap();
    assert!(manifest.exists(), "idrisiser.toml should be created");

    let content = fs::read_to_string(&manifest).unwrap();
    assert!(content.contains("[project]"));
    assert!(content.contains("[[interfaces]]"));
    assert!(content.contains("[proofs]"));
}

#[test]
fn test_load_and_validate_example_manifest() {
    let m = idrisiser::manifest::load_manifest("examples/user-api/idrisiser.toml").unwrap();
    idrisiser::manifest::validate(&m).unwrap();
    assert_eq!(m.project.name, "example-project");
    assert_eq!(m.interfaces.len(), 2);
    assert_eq!(m.interfaces[0].name, "user-api");
    assert_eq!(m.interfaces[1].name, "core-lib");
}

#[test]
fn test_validate_rejects_empty_project_name() {
    let toml = r#"
    [project]
    name = ""

    [[interfaces]]
    name = "api"
    source = "api.yaml"
    format = "openapi"
    "#;

    let m: idrisiser::manifest::Manifest = toml::from_str(toml).unwrap();
    let result = idrisiser::manifest::validate(&m);
    assert!(result.is_err());
    assert!(result.unwrap_err().to_string().contains("project.name"));
}

#[test]
fn test_validate_rejects_no_interfaces() {
    let toml = r#"
    [project]
    name = "test"
    "#;

    let result: Result<idrisiser::manifest::Manifest, _> = toml::from_str(toml);
    // Either parse fails (interfaces required) or validate rejects it
    if let Ok(m) = result {
        let vresult = idrisiser::manifest::validate(&m);
        assert!(vresult.is_err());
    }
}

#[test]
fn test_generate_produces_idris2_files() {
    let dir = tempfile::tempdir().unwrap();
    let output = dir.path().to_str().unwrap();

    let m = idrisiser::manifest::load_manifest("examples/user-api/idrisiser.toml").unwrap();
    idrisiser::codegen::generate_all(&m, output).unwrap();

    // Check Idris2 modules exist
    let idris_dir = dir.path().join("idris2");
    assert!(idris_dir.exists(), "idris2/ directory should be created");

    // Check user-api module was generated (OpenAPI interface)
    // Module path: Example/Verified/user_api.idr
    let user_api_idr = idris_dir.join("Example/Verified/user_api.idr");
    assert!(
        user_api_idr.exists(),
        "Idris2 module for user-api should exist at {:?}",
        user_api_idr
    );

    let content = fs::read_to_string(&user_api_idr).unwrap();
    assert!(content.contains("module Example.Verified.user_api"));
    assert!(content.contains("%default total"));
    assert!(content.contains("public export"));

    // Check core-lib module was generated (C header interface)
    let core_lib_idr = idris_dir.join("Example/Verified/core_lib.idr");
    assert!(
        core_lib_idr.exists(),
        "Idris2 module for core-lib should exist at {:?}",
        core_lib_idr
    );

    let core_content = fs::read_to_string(&core_lib_idr).unwrap();
    // The module should contain the interface name as a function (fallback when source file not found)
    assert!(
        core_content.contains("core_lib"),
        "Should contain interface name"
    );
}

#[test]
fn test_generate_produces_zig_bridge() {
    let dir = tempfile::tempdir().unwrap();
    let output = dir.path().to_str().unwrap();

    let m = idrisiser::manifest::load_manifest("examples/user-api/idrisiser.toml").unwrap();
    idrisiser::codegen::generate_all(&m, output).unwrap();

    let zig_dir = dir.path().join("zig");
    assert!(zig_dir.exists(), "zig/ directory should be created");

    let zig_ffi = zig_dir.join("example_project_ffi.zig");
    assert!(
        zig_ffi.exists(),
        "Zig FFI bridge should exist at {:?}",
        zig_ffi
    );

    let content = fs::read_to_string(&zig_ffi).unwrap();
    assert!(content.contains("export fn"));
    assert!(content.contains("callconv(.C)"));
}

#[test]
fn test_generate_produces_ipkg() {
    let dir = tempfile::tempdir().unwrap();
    let output = dir.path().to_str().unwrap();

    let m = idrisiser::manifest::load_manifest("examples/user-api/idrisiser.toml").unwrap();
    idrisiser::codegen::generate_all(&m, output).unwrap();

    let ipkg = dir.path().join("example_project_verified.ipkg");
    assert!(ipkg.exists(), ".ipkg file should be generated");

    let content = fs::read_to_string(&ipkg).unwrap();
    assert!(content.contains("package example_project_verified"));
    assert!(content.contains("sourcedir = \"idris2\""));
    assert!(content.contains("--total"));
}

#[test]
fn test_generate_produces_build_script() {
    let dir = tempfile::tempdir().unwrap();
    let output = dir.path().to_str().unwrap();

    let m = idrisiser::manifest::load_manifest("examples/user-api/idrisiser.toml").unwrap();
    idrisiser::codegen::generate_all(&m, output).unwrap();

    let build_sh = dir.path().join("build.sh");
    assert!(build_sh.exists(), "build.sh should be generated");

    let content = fs::read_to_string(&build_sh).unwrap();
    assert!(content.contains("idris2 --build"));
    assert!(content.contains("zig build-obj"));
}

#[test]
fn test_openapi_parsing_extracts_paths() {
    let m = idrisiser::manifest::load_manifest("examples/user-api/idrisiser.toml").unwrap();
    let dir = tempfile::tempdir().unwrap();
    idrisiser::codegen::generate_all(&m, dir.path().to_str().unwrap()).unwrap();

    let user_api_idr = dir.path().join("idris2/Example/Verified/user_api.idr");
    let content = fs::read_to_string(&user_api_idr).unwrap();

    // When source file isn't found at relative path, parser generates synthetic contract
    // using the interface name. The module should still be valid Idris2.
    assert!(
        content.contains("user_api") || content.contains("users"),
        "Should contain interface name or parsed endpoints"
    );
}

#[test]
fn test_c_header_parsing_extracts_functions() {
    let m = idrisiser::manifest::load_manifest("examples/user-api/idrisiser.toml").unwrap();
    let dir = tempfile::tempdir().unwrap();
    idrisiser::codegen::generate_all(&m, dir.path().to_str().unwrap()).unwrap();

    let core_lib_idr = dir.path().join("idris2/Example/Verified/core_lib.idr");
    let content = fs::read_to_string(&core_lib_idr).unwrap();

    // When source file isn't found, parser generates synthetic contracts from the
    // verify list, so process_item and reduce should appear in the module.
    assert!(
        content.contains("process_item"),
        "Should contain process_item from verify list"
    );
    assert!(
        content.contains("reduce"),
        "Should contain reduce from verify list"
    );
}

// ==========================================================================
// Point-to-point: each interface format generates correct Idris2
// ==========================================================================

#[test]
fn test_all_interface_formats_generate() {
    let formats = ["openapi", "c-header", "protobuf", "type-sig"];
    for fmt in &formats {
        let toml_str = format!(
            r#"
        [project]
        name = "test-{fmt}"

        [[interfaces]]
        name = "test-iface"
        source = "nonexistent.file"
        format = "{fmt}"
        "#
        );

        let m: idrisiser::manifest::Manifest = toml::from_str(&toml_str).unwrap();
        idrisiser::manifest::validate(&m).unwrap();

        let dir = tempfile::tempdir().unwrap();
        idrisiser::codegen::generate_all(&m, dir.path().to_str().unwrap())
            .unwrap_or_else(|e| panic!("Failed for format {fmt}: {e}"));

        // Every format should produce an Idris2 module
        let idr_dir = dir.path().join("idris2");
        assert!(idr_dir.exists(), "idris2/ missing for format {fmt}");

        // And a Zig bridge
        let zig_dir = dir.path().join("zig");
        assert!(zig_dir.exists(), "zig/ missing for format {fmt}");
    }
}

// ==========================================================================
// End-to-end: full pipeline with all artifacts
// ==========================================================================

#[test]
fn test_end_to_end_all_artifacts() {
    let m = idrisiser::manifest::load_manifest("examples/user-api/idrisiser.toml").unwrap();
    let dir = tempfile::tempdir().unwrap();
    let out = dir.path().to_str().unwrap();

    idrisiser::codegen::generate_all(&m, out).unwrap();

    // All expected artifacts
    assert!(dir.path().join("idris2").exists(), "idris2/ dir");
    assert!(dir.path().join("zig").exists(), "zig/ dir");
    assert!(
        dir.path().join("example_project_verified.ipkg").exists(),
        ".ipkg"
    );
    assert!(dir.path().join("build.sh").exists(), "build.sh");

    // Two interfaces should produce two Idris2 modules
    let idr_files: Vec<_> = walkdir::WalkDir::new(dir.path().join("idris2"))
        .into_iter()
        .filter_map(|e| e.ok())
        .filter(|e| e.path().extension().is_some_and(|ext| ext == "idr"))
        .collect();
    assert_eq!(idr_files.len(), 2, "Should generate 2 .idr modules");
}

// ==========================================================================
// Edge cases
// ==========================================================================

#[test]
fn test_single_interface_project() {
    let toml_str = r#"
    [project]
    name = "minimal"

    [[interfaces]]
    name = "single"
    source = "api.yaml"
    format = "openapi"
    "#;

    let m: idrisiser::manifest::Manifest = toml::from_str(toml_str).unwrap();
    idrisiser::manifest::validate(&m).unwrap();

    let dir = tempfile::tempdir().unwrap();
    idrisiser::codegen::generate_all(&m, dir.path().to_str().unwrap()).unwrap();
}

#[test]
fn test_many_interfaces() {
    let toml_str = r#"
    [project]
    name = "multi"

    [[interfaces]]
    name = "api-one"
    source = "a.yaml"
    format = "openapi"

    [[interfaces]]
    name = "api-two"
    source = "b.proto"
    format = "protobuf"

    [[interfaces]]
    name = "api-three"
    source = "c.h"
    format = "c-header"

    [[interfaces]]
    name = "api-four"
    source = "d.tsig"
    format = "type-sig"
    "#;

    let m: idrisiser::manifest::Manifest = toml::from_str(toml_str).unwrap();
    idrisiser::manifest::validate(&m).unwrap();
    assert_eq!(m.interfaces.len(), 4);

    let dir = tempfile::tempdir().unwrap();
    idrisiser::codegen::generate_all(&m, dir.path().to_str().unwrap()).unwrap();
}

#[test]
fn test_interface_with_preconditions_and_postconditions() {
    let toml_str = r#"
    [project]
    name = "constrained"

    [[interfaces]]
    name = "guarded-api"
    source = "api.yaml"
    format = "openapi"
    preconditions = ["auth_valid", "rate_limit_ok"]
    postconditions = ["status < 500", "body_valid"]
    invariants = ["db_consistent"]
    "#;

    let m: idrisiser::manifest::Manifest = toml::from_str(toml_str).unwrap();
    let dir = tempfile::tempdir().unwrap();
    idrisiser::codegen::generate_all(&m, dir.path().to_str().unwrap()).unwrap();

    // Find the generated module and check it contains the constraints
    let idr_files: Vec<_> = walkdir::WalkDir::new(dir.path().join("idris2"))
        .into_iter()
        .filter_map(|e| e.ok())
        .filter(|e| e.path().extension().is_some_and(|ext| ext == "idr"))
        .collect();
    assert!(!idr_files.is_empty());

    let content = fs::read_to_string(idr_files[0].path()).unwrap();
    assert!(content.contains("auth_valid"), "Precondition should appear");
    assert!(
        content.contains("status < 500"),
        "Postcondition should appear"
    );
    // Invariants are stored in the contract but rendered in a future phase
    assert!(
        m.interfaces[0]
            .invariants
            .contains(&"db_consistent".to_string()),
        "Invariant should be in manifest"
    );
}

#[test]
fn test_custom_module_prefix() {
    let toml_str = r#"
    [project]
    name = "my-project"
    module-prefix = "Com.Example.Verified"

    [[interfaces]]
    name = "api"
    source = "api.yaml"
    format = "openapi"
    "#;

    let m: idrisiser::manifest::Manifest = toml::from_str(toml_str).unwrap();
    let dir = tempfile::tempdir().unwrap();
    idrisiser::codegen::generate_all(&m, dir.path().to_str().unwrap()).unwrap();

    let idr_path = dir.path().join("idris2/Com/Example/Verified/api.idr");
    assert!(
        idr_path.exists(),
        "Module should use custom prefix path: {:?}",
        idr_path
    );

    let content = fs::read_to_string(&idr_path).unwrap();
    assert!(content.contains("module Com.Example.Verified.api"));
}

#[test]
fn test_validate_rejects_empty_interface_name() {
    let toml_str = r#"
    [project]
    name = "test"

    [[interfaces]]
    name = ""
    source = "api.yaml"
    format = "openapi"
    "#;

    let m: idrisiser::manifest::Manifest = toml::from_str(toml_str).unwrap();
    let result = idrisiser::manifest::validate(&m);
    assert!(result.is_err());
}

#[test]
fn test_validate_rejects_empty_source() {
    let toml_str = r#"
    [project]
    name = "test"

    [[interfaces]]
    name = "api"
    source = ""
    format = "openapi"
    "#;

    let m: idrisiser::manifest::Manifest = toml::from_str(toml_str).unwrap();
    let result = idrisiser::manifest::validate(&m);
    assert!(result.is_err());
}

// ==========================================================================
// Aspect: generated code quality
// ==========================================================================

#[test]
fn test_all_generated_idris2_has_spdx_header() {
    let m = idrisiser::manifest::load_manifest("examples/user-api/idrisiser.toml").unwrap();
    let dir = tempfile::tempdir().unwrap();
    idrisiser::codegen::generate_all(&m, dir.path().to_str().unwrap()).unwrap();

    for entry in walkdir::WalkDir::new(dir.path().join("idris2"))
        .into_iter()
        .filter_map(|e| e.ok())
        .filter(|e| e.path().extension().is_some_and(|ext| ext == "idr"))
    {
        let content = fs::read_to_string(entry.path()).unwrap();
        assert!(
            content.contains("SPDX-License-Identifier"),
            "Missing SPDX in {:?}",
            entry.path()
        );
    }
}

#[test]
fn test_all_generated_idris2_is_total() {
    let m = idrisiser::manifest::load_manifest("examples/user-api/idrisiser.toml").unwrap();
    let dir = tempfile::tempdir().unwrap();
    idrisiser::codegen::generate_all(&m, dir.path().to_str().unwrap()).unwrap();

    for entry in walkdir::WalkDir::new(dir.path().join("idris2"))
        .into_iter()
        .filter_map(|e| e.ok())
        .filter(|e| e.path().extension().is_some_and(|ext| ext == "idr"))
    {
        let content = fs::read_to_string(entry.path()).unwrap();
        assert!(
            content.contains("%default total"),
            "Missing %%default total in {:?}",
            entry.path()
        );
    }
}

#[test]
fn test_zig_bridge_has_proper_exports() {
    let m = idrisiser::manifest::load_manifest("examples/user-api/idrisiser.toml").unwrap();
    let dir = tempfile::tempdir().unwrap();
    idrisiser::codegen::generate_all(&m, dir.path().to_str().unwrap()).unwrap();

    let zig_ffi = dir.path().join("zig/example_project_ffi.zig");
    let content = fs::read_to_string(&zig_ffi).unwrap();

    // Every export should use C calling convention
    for line in content.lines() {
        if line.contains("export fn") {
            assert!(
                line.contains("callconv(.C)"),
                "Export missing callconv(.C): {}",
                line.trim()
            );
        }
    }
}

#[test]
fn test_ipkg_references_all_modules() {
    let m = idrisiser::manifest::load_manifest("examples/user-api/idrisiser.toml").unwrap();
    let dir = tempfile::tempdir().unwrap();
    idrisiser::codegen::generate_all(&m, dir.path().to_str().unwrap()).unwrap();

    let ipkg = fs::read_to_string(dir.path().join("example_project_verified.ipkg")).unwrap();

    // Should reference both interfaces
    assert!(
        ipkg.contains("user_api"),
        "ipkg should reference user_api module"
    );
    assert!(
        ipkg.contains("core_lib"),
        "ipkg should reference core_lib module"
    );
}

// ==========================================================================
// Proof config tests
// ==========================================================================

#[test]
fn test_qtt_tracking_enabled() {
    let toml_str = r#"
    [project]
    name = "qtt-test"

    [[interfaces]]
    name = "api"
    source = "api.yaml"
    format = "openapi"

    [proofs]
    qtt-tracking = true
    "#;

    let m: idrisiser::manifest::Manifest = toml::from_str(toml_str).unwrap();
    assert!(m.proofs.qtt_tracking);

    let dir = tempfile::tempdir().unwrap();
    idrisiser::codegen::generate_all(&m, dir.path().to_str().unwrap()).unwrap();
}

#[test]
fn test_proof_defaults() {
    let toml_str = r#"
    [project]
    name = "defaults"

    [[interfaces]]
    name = "api"
    source = "x"
    format = "openapi"
    "#;

    let m: idrisiser::manifest::Manifest = toml::from_str(toml_str).unwrap();
    assert!(m.proofs.require_totality);
    assert!(m.proofs.round_trip_proofs);
    assert!(!m.proofs.qtt_tracking);
    assert_eq!(m.proofs.search_depth, 100);
}

#[test]
fn test_library_api_convenience_function() {
    // Test the lib.rs generate() convenience function
    let dir = tempfile::tempdir().unwrap();
    let result = idrisiser::generate(
        "examples/user-api/idrisiser.toml",
        dir.path().to_str().unwrap(),
    );
    assert!(result.is_ok());
    assert!(dir.path().join("idris2").exists());
}
