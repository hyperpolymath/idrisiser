// Idrisiser FFI Implementation
//
// This module implements the C-compatible FFI declared in src/interface/abi/Foreign.idr.
// All types, result codes, and function signatures must exactly match the Idris2 ABI
// definitions.  The Zig layer handles memory allocation, error storage, and the
// concrete implementation of proof engine operations that Idris2 calls through FFI.
//
// SPDX-License-Identifier: PMPL-1.0-or-later
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>

const std = @import("std");

// Version information (keep in sync with Cargo.toml and ABI declarations)
const VERSION = "0.1.0";
const BUILD_INFO = "idrisiser built with Zig " ++ @import("builtin").zig_version_string;

/// Thread-local error storage for the last error message.
/// Accessed via idrisiser_last_error() from the Idris2 side.
threadlocal var last_error: ?[]const u8 = null;

/// Set the last error message
fn setError(msg: []const u8) void {
    last_error = msg;
}

/// Clear the last error (call after successful operations)
fn clearError() void {
    last_error = null;
}

//==============================================================================
// Core Types (must match Idrisiser.ABI.Types)
//==============================================================================

/// Result codes matching the Idris2 Result type in Types.idr.
/// The integer values are used for FFI crossing and must stay in sync.
pub const Result = enum(c_int) {
    ok = 0,
    @"error" = 1,
    invalid_param = 2,
    out_of_memory = 3,
    null_pointer = 4,
    proof_failure = 5,
};

/// Interface format codes matching InterfaceFormat in Types.idr.
pub const InterfaceFormat = enum(u32) {
    openapi = 0,
    c_header = 1,
    protobuf = 2,
    type_sig = 3,
};

/// Internal state for the proof engine.
/// Opaque to C callers — only accessible through the handle-based API.
const EngineState = struct {
    allocator: std.mem.Allocator,
    initialized: bool,
    /// Number of proof obligations generated from the current interface
    obligation_count: u32,
    /// Number of obligations that have been discharged (proven)
    discharged_count: u32,
    /// Whether an interface has been parsed and loaded
    interface_loaded: bool,
    /// Whether proofs have been compiled
    proofs_compiled: bool,
};

//==============================================================================
// Proof Engine Lifecycle
//==============================================================================

/// Initialise the Idrisiser proof engine.
/// Allocates an EngineState and returns an opaque handle.
/// Returns null on allocation failure.
export fn idrisiser_init() ?*anyopaque {
    const allocator = std.heap.c_allocator;

    const state = allocator.create(EngineState) catch {
        setError("Failed to allocate engine state");
        return null;
    };

    state.* = .{
        .allocator = allocator,
        .initialized = true,
        .obligation_count = 0,
        .discharged_count = 0,
        .interface_loaded = false,
        .proofs_compiled = false,
    };

    clearError();
    return @ptrCast(state);
}

/// Free the proof engine handle and release all resources.
export fn idrisiser_free(handle: ?*anyopaque) void {
    const state = stateFromHandle(handle) orelse return;
    const allocator = state.allocator;
    state.initialized = false;
    allocator.destroy(state);
    clearError();
}

/// Check whether the engine handle is live and initialised.
/// Returns 1 if initialised, 0 otherwise.
export fn idrisiser_is_initialized(handle: ?*anyopaque) u32 {
    const state = stateFromHandle(handle) orelse return 0;
    return if (state.initialized) 1 else 0;
}

//==============================================================================
// Interface Parsing
//==============================================================================

/// Parse an interface definition file and load it into the engine.
/// path_ptr: pointer to a null-terminated file path string.
/// format: interface format code (0=OpenAPI, 1=CHeader, 2=ProtoBuf, 3=TypeSig).
/// Returns 0 on success, non-zero Result code on failure.
export fn idrisiser_parse_interface(
    handle: ?*anyopaque,
    path_ptr: u64,
    format: u32,
) c_int {
    const state = stateFromHandle(handle) orelse {
        setError("Null engine handle");
        return @intFromEnum(Result.null_pointer);
    };

    if (!state.initialized) {
        setError("Engine not initialized");
        return @intFromEnum(Result.@"error");
    }

    if (path_ptr == 0) {
        setError("Null file path pointer");
        return @intFromEnum(Result.null_pointer);
    }

    // Validate format code
    if (format > 3) {
        setError("Unknown interface format code");
        return @intFromEnum(Result.invalid_param);
    }

    // TODO: implement actual interface parsing for each format
    // For now, mark the interface as loaded
    state.interface_loaded = true;
    state.obligation_count = 0;
    state.discharged_count = 0;
    state.proofs_compiled = false;

    clearError();
    return @intFromEnum(Result.ok);
}

//==============================================================================
// Proof Generation
//==============================================================================

/// Generate proof obligations from the currently loaded interface.
/// Returns the number of obligations generated, or 0 on failure.
export fn idrisiser_generate_proofs(handle: ?*anyopaque) u32 {
    const state = stateFromHandle(handle) orelse {
        setError("Null engine handle");
        return 0;
    };

    if (!state.initialized) {
        setError("Engine not initialized");
        return 0;
    }

    if (!state.interface_loaded) {
        setError("No interface loaded — call idrisiser_parse_interface first");
        return 0;
    }

    // TODO: implement proof obligation derivation from parsed interface
    // For now, return a placeholder count
    state.obligation_count = 0;
    state.discharged_count = 0;
    state.proofs_compiled = false;

    clearError();
    return state.obligation_count;
}

/// Compile all generated proof obligations through the Idris2 type checker.
/// Returns 0 if all proofs pass, non-zero on proof failure.
export fn idrisiser_compile_proofs(handle: ?*anyopaque) c_int {
    const state = stateFromHandle(handle) orelse {
        setError("Null engine handle");
        return @intFromEnum(Result.null_pointer);
    };

    if (!state.initialized) {
        setError("Engine not initialized");
        return @intFromEnum(Result.@"error");
    }

    if (state.obligation_count == 0) {
        setError("No proof obligations — call idrisiser_generate_proofs first");
        return @intFromEnum(Result.@"error");
    }

    // TODO: invoke Idris2 compiler on generated .idr files
    // Check totality, elaborator reflection, QTT
    state.proofs_compiled = true;
    state.discharged_count = state.obligation_count;

    clearError();
    return @intFromEnum(Result.ok);
}

//==============================================================================
// Proof Checking and Results
//==============================================================================

/// Query the number of discharged (successfully proven) obligations.
export fn idrisiser_discharged_count(handle: ?*anyopaque) u32 {
    const state = stateFromHandle(handle) orelse return 0;
    return state.discharged_count;
}

/// Query the number of remaining (unproven) obligations.
export fn idrisiser_remaining_count(handle: ?*anyopaque) u32 {
    const state = stateFromHandle(handle) orelse return 0;
    return state.obligation_count - state.discharged_count;
}

//==============================================================================
// Native Wrapper Output
//==============================================================================

/// Emit the native wrapper to the specified output path.
/// Must be called after all proofs are compiled and discharged.
export fn idrisiser_emit_wrapper(
    handle: ?*anyopaque,
    output_path_ptr: u64,
) c_int {
    const state = stateFromHandle(handle) orelse {
        setError("Null engine handle");
        return @intFromEnum(Result.null_pointer);
    };

    if (!state.initialized) {
        setError("Engine not initialized");
        return @intFromEnum(Result.@"error");
    }

    if (!state.proofs_compiled) {
        setError("Proofs not compiled — call idrisiser_compile_proofs first");
        return @intFromEnum(Result.@"error");
    }

    if (state.discharged_count != state.obligation_count) {
        setError("Not all proof obligations discharged");
        return @intFromEnum(Result.proof_failure);
    }

    if (output_path_ptr == 0) {
        setError("Null output path");
        return @intFromEnum(Result.null_pointer);
    }

    // TODO: emit .so / .a / .dylib / .dll to output path

    clearError();
    return @intFromEnum(Result.ok);
}

//==============================================================================
// String Operations
//==============================================================================

/// Get a diagnostic string result from the engine.
/// Caller must free the returned string via idrisiser_free_string.
export fn idrisiser_get_string(handle: ?*anyopaque) ?[*:0]const u8 {
    const state = stateFromHandle(handle) orelse {
        setError("Null engine handle");
        return null;
    };

    if (!state.initialized) {
        setError("Engine not initialized");
        return null;
    }

    const result = state.allocator.dupeZ(u8, "idrisiser engine active") catch {
        setError("Failed to allocate string");
        return null;
    };

    clearError();
    return result.ptr;
}

/// Free a string allocated by the engine.
export fn idrisiser_free_string(str: ?[*:0]const u8) void {
    const s = str orelse return;
    const allocator = std.heap.c_allocator;
    const slice = std.mem.span(s);
    allocator.free(slice);
}

//==============================================================================
// Error Handling
//==============================================================================

/// Get the last error message.  Returns null if no error.
/// The returned string must be freed by the caller.
export fn idrisiser_last_error() ?[*:0]const u8 {
    const err = last_error orelse return null;
    const allocator = std.heap.c_allocator;
    const c_str = allocator.dupeZ(u8, err) catch return null;
    return c_str.ptr;
}

//==============================================================================
// Version Information
//==============================================================================

/// Get the engine version string (static, do not free)
export fn idrisiser_version() [*:0]const u8 {
    return VERSION.ptr;
}

/// Get build information string (static, do not free)
export fn idrisiser_build_info() [*:0]const u8 {
    return BUILD_INFO.ptr;
}

//==============================================================================
// Internal Helpers
//==============================================================================

/// Cast an opaque handle pointer to a typed EngineState pointer.
/// Returns null if the handle is null.
fn stateFromHandle(handle: ?*anyopaque) ?*EngineState {
    const ptr = handle orelse return null;
    return @ptrCast(@alignCast(ptr));
}

//==============================================================================
// Tests
//==============================================================================

test "lifecycle: init and free" {
    const handle = idrisiser_init() orelse return error.InitFailed;
    defer idrisiser_free(handle);

    try std.testing.expect(idrisiser_is_initialized(handle) == 1);
}

test "error handling: null handle returns null_pointer" {
    const result = idrisiser_parse_interface(null, 0, 0);
    try std.testing.expectEqual(@as(c_int, @intFromEnum(Result.null_pointer)), result);

    const err = idrisiser_last_error();
    try std.testing.expect(err != null);
}

test "version string is semantic version" {
    const ver = idrisiser_version();
    const ver_str = std.mem.span(ver);
    try std.testing.expectEqualStrings(VERSION, ver_str);
}

test "proof workflow requires correct ordering" {
    const handle = idrisiser_init() orelse return error.InitFailed;
    defer idrisiser_free(handle);

    // Cannot compile proofs without generating them first
    const compile_result = idrisiser_compile_proofs(handle);
    try std.testing.expect(compile_result != @intFromEnum(Result.ok));

    // Cannot emit wrapper without compiled proofs
    const emit_result = idrisiser_emit_wrapper(handle, 0);
    try std.testing.expect(emit_result != @intFromEnum(Result.ok));
}
