// Idrisiser FFI Build Configuration
//
// Builds the Zig FFI shared and static libraries that implement the
// C-compatible functions declared in src/interface/abi/Foreign.idr.
//
// SPDX-License-Identifier: PMPL-1.0-or-later
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>

const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Shared library (.so / .dylib / .dll)
    // This is the primary output consumed by the Idris2 FFI layer.
    const lib = b.addSharedLibrary(.{
        .name = "idrisiser",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    lib.version = .{ .major = 0, .minor = 1, .patch = 0 };

    // Static library (.a) for embedding in larger binaries
    const lib_static = b.addStaticLibrary(.{
        .name = "idrisiser",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Install both library variants
    b.installArtifact(lib);
    b.installArtifact(lib_static);

    // Install the C header for consumers that link against libidrisiser
    const header = b.addInstallHeader(
        b.path("include/idrisiser.h"),
        "idrisiser.h",
    );
    b.getInstallStep().dependOn(&header.step);

    // Unit tests (run tests embedded in src/main.zig)
    const lib_tests = b.addTest(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_lib_tests = b.addRunArtifact(lib_tests);

    const test_step = b.step("test", "Run FFI unit tests");
    test_step.dependOn(&run_lib_tests.step);

    // Integration tests (verify ABI ↔ FFI agreement)
    const integration_tests = b.addTest(.{
        .root_source_file = b.path("test/integration_test.zig"),
        .target = target,
        .optimize = optimize,
    });

    integration_tests.linkLibrary(lib);

    const run_integration_tests = b.addRunArtifact(integration_tests);

    const integration_test_step = b.step("test-integration", "Run ABI↔FFI integration tests");
    integration_test_step.dependOn(&run_integration_tests.step);

    // Documentation generation
    const docs = b.addTest(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = .Debug,
    });

    const docs_step = b.step("docs", "Generate FFI API documentation");
    docs_step.dependOn(&b.addInstallDirectory(.{
        .source_dir = docs.getEmittedDocs(),
        .install_dir = .prefix,
        .install_subdir = "docs",
    }).step);

    // Benchmark harness (for proof compilation throughput)
    const bench = b.addExecutable(.{
        .name = "idrisiser-bench",
        .root_source_file = b.path("bench/bench.zig"),
        .target = target,
        .optimize = .ReleaseFast,
    });

    bench.linkLibrary(lib);

    const run_bench = b.addRunArtifact(bench);

    const bench_step = b.step("bench", "Run proof compilation benchmarks");
    bench_step.dependOn(&run_bench.step);
}
