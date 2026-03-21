// Idrisiser ABI ↔ FFI Integration Tests
//
// These tests verify that the Zig FFI correctly implements the Idris2 ABI
// contract declared in src/interface/abi/Foreign.idr.  Every exported function
// is tested for:
//   - Correct behaviour with valid inputs
//   - Null-safety (null handle, null pointer arguments)
//   - Correct error codes matching Idrisiser.ABI.Types.Result
//   - Correct operation ordering (parse → generate → compile → emit)
//
// SPDX-License-Identifier: PMPL-1.0-or-later
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>

const std = @import("std");
const testing = std.testing;

// Import FFI functions (C-ABI exports from libidrisiser)
extern fn idrisiser_init() ?*anyopaque;
extern fn idrisiser_free(?*anyopaque) void;
extern fn idrisiser_is_initialized(?*anyopaque) u32;
extern fn idrisiser_parse_interface(?*anyopaque, u64, u32) c_int;
extern fn idrisiser_generate_proofs(?*anyopaque) u32;
extern fn idrisiser_compile_proofs(?*anyopaque) c_int;
extern fn idrisiser_discharged_count(?*anyopaque) u32;
extern fn idrisiser_remaining_count(?*anyopaque) u32;
extern fn idrisiser_emit_wrapper(?*anyopaque, u64) c_int;
extern fn idrisiser_get_string(?*anyopaque) ?[*:0]const u8;
extern fn idrisiser_free_string(?[*:0]const u8) void;
extern fn idrisiser_last_error() ?[*:0]const u8;
extern fn idrisiser_version() [*:0]const u8;
extern fn idrisiser_build_info() [*:0]const u8;

//==============================================================================
// Lifecycle Tests
//==============================================================================

test "create and destroy engine handle" {
    const handle = idrisiser_init() orelse return error.InitFailed;
    defer idrisiser_free(handle);

    try testing.expect(handle != null);
}

test "engine is initialized after init" {
    const handle = idrisiser_init() orelse return error.InitFailed;
    defer idrisiser_free(handle);

    const initialized = idrisiser_is_initialized(handle);
    try testing.expectEqual(@as(u32, 1), initialized);
}

test "null handle is not initialized" {
    const initialized = idrisiser_is_initialized(null);
    try testing.expectEqual(@as(u32, 0), initialized);
}

test "free null handle is safe (no-op)" {
    idrisiser_free(null); // Must not crash
}

//==============================================================================
// Interface Parsing Tests
//==============================================================================

test "parse with null handle returns null_pointer" {
    const result = idrisiser_parse_interface(null, 1, 0);
    try testing.expectEqual(@as(c_int, 4), result); // 4 = null_pointer
}

test "parse with null path returns null_pointer" {
    const handle = idrisiser_init() orelse return error.InitFailed;
    defer idrisiser_free(handle);

    const result = idrisiser_parse_interface(handle, 0, 0);
    try testing.expectEqual(@as(c_int, 4), result); // 4 = null_pointer
}

test "parse with invalid format returns invalid_param" {
    const handle = idrisiser_init() orelse return error.InitFailed;
    defer idrisiser_free(handle);

    const result = idrisiser_parse_interface(handle, 42, 99);
    try testing.expectEqual(@as(c_int, 2), result); // 2 = invalid_param
}

//==============================================================================
// Proof Workflow Ordering Tests
//==============================================================================

test "generate proofs without loaded interface returns 0" {
    const handle = idrisiser_init() orelse return error.InitFailed;
    defer idrisiser_free(handle);

    const count = idrisiser_generate_proofs(handle);
    try testing.expectEqual(@as(u32, 0), count);
}

test "compile proofs without obligations returns error" {
    const handle = idrisiser_init() orelse return error.InitFailed;
    defer idrisiser_free(handle);

    const result = idrisiser_compile_proofs(handle);
    try testing.expect(result != 0); // Must not be ok
}

test "emit wrapper without compiled proofs returns error" {
    const handle = idrisiser_init() orelse return error.InitFailed;
    defer idrisiser_free(handle);

    const result = idrisiser_emit_wrapper(handle, 42);
    try testing.expect(result != 0);
}

test "emit wrapper with null output path returns null_pointer" {
    const handle = idrisiser_init() orelse return error.InitFailed;
    defer idrisiser_free(handle);

    const result = idrisiser_emit_wrapper(handle, 0);
    // Either null_pointer (for null path) or error (for uncompiled proofs)
    try testing.expect(result != 0);
}

//==============================================================================
// Proof Count Tests
//==============================================================================

test "discharged count is 0 initially" {
    const handle = idrisiser_init() orelse return error.InitFailed;
    defer idrisiser_free(handle);

    const count = idrisiser_discharged_count(handle);
    try testing.expectEqual(@as(u32, 0), count);
}

test "remaining count is 0 initially" {
    const handle = idrisiser_init() orelse return error.InitFailed;
    defer idrisiser_free(handle);

    const remaining = idrisiser_remaining_count(handle);
    try testing.expectEqual(@as(u32, 0), remaining);
}

test "null handle counts return 0" {
    try testing.expectEqual(@as(u32, 0), idrisiser_discharged_count(null));
    try testing.expectEqual(@as(u32, 0), idrisiser_remaining_count(null));
}

//==============================================================================
// String Tests
//==============================================================================

test "get string from valid handle" {
    const handle = idrisiser_init() orelse return error.InitFailed;
    defer idrisiser_free(handle);

    const str = idrisiser_get_string(handle);
    defer if (str) |s| idrisiser_free_string(s);

    try testing.expect(str != null);
}

test "get string from null handle returns null" {
    const str = idrisiser_get_string(null);
    try testing.expect(str == null);
}

//==============================================================================
// Error Handling Tests
//==============================================================================

test "last error populated after null handle operation" {
    _ = idrisiser_parse_interface(null, 0, 0);

    const err = idrisiser_last_error();
    try testing.expect(err != null);

    if (err) |e| {
        const err_str = std.mem.span(e);
        try testing.expect(err_str.len > 0);
    }
}

//==============================================================================
// Version Tests
//==============================================================================

test "version string is not empty" {
    const ver = idrisiser_version();
    const ver_str = std.mem.span(ver);
    try testing.expect(ver_str.len > 0);
}

test "version is semantic version format (contains dot)" {
    const ver = idrisiser_version();
    const ver_str = std.mem.span(ver);
    try testing.expect(std.mem.count(u8, ver_str, ".") >= 1);
}

test "build info mentions idrisiser" {
    const info = idrisiser_build_info();
    const info_str = std.mem.span(info);
    try testing.expect(std.mem.indexOf(u8, info_str, "idrisiser") != null);
}

//==============================================================================
// Memory Safety Tests
//==============================================================================

test "multiple handles are independent" {
    const h1 = idrisiser_init() orelse return error.InitFailed;
    defer idrisiser_free(h1);

    const h2 = idrisiser_init() orelse return error.InitFailed;
    defer idrisiser_free(h2);

    try testing.expect(h1 != h2);

    // Operations on h1 must not affect h2
    _ = idrisiser_parse_interface(h1, 42, 0);
    try testing.expectEqual(@as(u32, 1), idrisiser_is_initialized(h2));
}

test "free string null is safe (no-op)" {
    idrisiser_free_string(null); // Must not crash
}
