#!/usr/bin/env julia
# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
#
# abi-ffi-gate.jl — fail (exit 1) if the Zig FFI does not conform to the Idris2
# ABI. The Idris2 ABI is the source of truth. Checks, with no compile toolchain
# needed (pure base-Julia text analysis):
#
#   1. the Zig FFI carries no unrendered `{{...}}` template tokens;
#   2. every `%foreign "C:<name>"` symbol declared anywhere in the ABI .idr
#      sources is exported by the Zig FFI (`export fn <name>`);
#   3. the Zig `Result = enum(c_int)` and the Idris `resultToInt` agree on BOTH
#      names and integer values (the `Error`/`err` spelling is treated as one).
#
# Usage: julia scripts/abi-ffi-gate.jl [repo_root]   (defaults to cwd)
#
# Julia port of the former scripts/abi-ffi-gate.py (Python is banned estate-wide,
# RSR-H4); behaviour is identical.

"camelCase / PascalCase → snake_case (insert `_` before each non-initial capital)."
camel_to_snake(s) = lowercase(replace(s, r"(?<!^)(?=[A-Z])" => "_"))

"Canonical result-code key: lowercased, with `err`/`error` unified to `error`."
function canon_rc(name)
    n = lowercase(name)
    (n == "err" || n == "error") ? "error" : n
end

"Return {variant => value} for the C-ABI `Result` enum (the `enum(c_int)` block whose `ok = 0`), or empty."
function find_result_enum(zig::AbstractString)
    best = Dict{String,Int}()
    for m in eachmatch(r"enum\s*\(\s*c_int\s*\)\s*\{(.*?)\}"s, zig)
        body = m.captures[1]
        variants = Dict{String,Int}()
        for vm in eachmatch(r"@?\"?([A-Za-z_][A-Za-z0-9_]*)\"?\s*=\s*(\d+)", body)
            variants[canon_rc(vm.captures[1])] = parse(Int, vm.captures[2])
        end
        # The Result enum is the one starting at ok = 0.
        if get(variants, "ok", nothing) == 0 && length(variants) > length(best)
            best = variants
        end
    end
    return best
end

"Collect every `*.idr` under `abi_dir`, skipping any `build/` output directory."
function idr_sources(abi_dir::AbstractString)
    files = String[]
    isdir(abi_dir) || return files
    for (root, _dirs, fs) in walkdir(abi_dir)
        occursin("/build/", root * "/") && continue
        for f in fs
            endswith(f, ".idr") && push!(files, joinpath(root, f))
        end
    end
    return files
end

function main(root::AbstractString)::Int
    name = basename(rstrip(abspath(root), '/'))
    abi_dir = joinpath(root, "src/interface/abi")
    zig_path = joinpath(root, "src/interface/ffi/src/main.zig")
    errs = String[]

    idr_files = idr_sources(abi_dir)
    if isempty(idr_files)
        println("ABI-FFI GATE: SKIP ($name) — no Idris2 ABI .idr files under $abi_dir")
        return 0
    end
    if !isfile(zig_path)
        println("ABI-FFI GATE: FAIL ($name) — no Zig FFI at $zig_path")
        return 1
    end

    idr = join((read(p, String) for p in idr_files), "\n")
    zig = read(zig_path, String)

    # 1. unrendered template tokens
    toks = sort(unique(String(m.match) for m in eachmatch(r"\{\{[A-Za-z0-9_]+\}\}", zig)))
    isempty(toks) || push!(errs, "Zig FFI has unrendered template tokens: $(toks)")

    # 2. foreign C symbols must be exported
    csyms = sort(unique(String(m.captures[1]) for m in eachmatch(r"C:([A-Za-z0-9_]+)", idr)))
    exports = Set(String(m.captures[1]) for m in eachmatch(r"export fn ([A-Za-z0-9_]+)", zig))
    missing_syms = [s for s in csyms if !(s in exports)]
    isempty(missing_syms) ||
        push!(errs, "$(length(missing_syms)) ABI function(s) not exported by the Zig FFI: $(missing_syms)")

    # 3. result-code map (names + values) must agree
    idr_rc = Dict{String,Int}()
    for m in eachmatch(r"resultToInt\s+([A-Za-z0-9]+)\s*=\s*(\d+)", idr)
        idr_rc[canon_rc(camel_to_snake(m.captures[1]))] = parse(Int, m.captures[2])
    end
    zig_rc = find_result_enum(zig)
    if !isempty(idr_rc) && isempty(zig_rc)
        push!(errs, "no Zig `enum(c_int)` Result block (with `ok = 0`) found to compare result codes")
    elseif !isempty(idr_rc) && !isempty(zig_rc) && idr_rc != zig_rc
        push!(errs, "Result-code map differs (name or value):\n" *
                    "      Idris resultToInt: $(sort(collect(idr_rc)))\n" *
                    "      Zig   Result enum: $(sort(collect(zig_rc)))")
    end

    if !isempty(errs)
        println("ABI-FFI GATE: FAIL ($name)")
        for e in errs
            println("  - " * e)
        end
        return 1
    end
    println("ABI-FFI GATE: OK ($name) — $(length(csyms)) ABI functions exported, " *
            "$(length(idr_rc)) result codes match")
    return 0
end

root = length(ARGS) >= 1 ? ARGS[1] : "."
exit(main(root))
