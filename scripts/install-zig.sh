#!/bin/sh
# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
#
# install-zig.sh — install the pinned Zig toolchain (the Zig FFI bridge half of
# the ABI-FFI standard). Idempotent and fail-soft: it never aborts the caller.
#
# Egress note: Zig is NOT distributed via GitHub releases, so it is fetched from
# ziglang.org. Inside a Claude Code session, outbound HTTPS goes through the
# policy-enforcing agent proxy; github.com is allowlisted by default but
# ziglang.org must be added explicitly, or this download returns 403. We use the
# system CA store the proxy already populated — never pass --insecure.
set -eu

ZIG_VERSION="${ZIG_VERSION:-0.14.0}"
PREFIX="${ZIG_PREFIX:-/usr/local}"

# Already at the pinned version? Done.
if command -v zig >/dev/null 2>&1 && [ "$(zig version 2>/dev/null)" = "$ZIG_VERSION" ]; then
  echo "install-zig: zig $ZIG_VERSION already installed"
  exit 0
fi

# Map host arch/OS to Zig's release naming.
case "$(uname -m)" in
  x86_64|amd64)   zarch="x86_64" ;;
  aarch64|arm64)  zarch="aarch64" ;;
  *) echo "install-zig: unsupported arch $(uname -m); install Zig $ZIG_VERSION manually" >&2; exit 0 ;;
esac
case "$(uname -s)" in
  Linux)   zos="linux" ;;
  Darwin)  zos="macos" ;;
  *) echo "install-zig: unsupported OS $(uname -s); install Zig $ZIG_VERSION manually" >&2; exit 0 ;;
esac

tarball="zig-${zos}-${zarch}-${ZIG_VERSION}.tar.xz"
url="https://ziglang.org/download/${ZIG_VERSION}/${tarball}"
dest="${PREFIX}/lib/zig-${ZIG_VERSION}"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

echo "install-zig: fetching $url"
if ! curl -fsSL --retry 2 -o "$tmp/$tarball" "$url"; then
  echo "install-zig: download failed (HTTP error or blocked host)." >&2
  echo "install-zig: if this is a Claude Code session, add 'ziglang.org' to the" >&2
  echo "             egress allowlist — github.com is allowed but ziglang.org is not." >&2
  exit 0   # fail-soft: a missing Zig must not block setup or session start
fi

mkdir -p "$dest" "${PREFIX}/bin"
tar -xJf "$tmp/$tarball" -C "$dest" --strip-components=1
ln -sf "$dest/zig" "${PREFIX}/bin/zig"

if command -v zig >/dev/null 2>&1 && [ "$(zig version 2>/dev/null)" = "$ZIG_VERSION" ]; then
  echo "install-zig: installed zig $(zig version)"
else
  echo "install-zig: installed to ${PREFIX}/bin/zig — ensure ${PREFIX}/bin is on PATH" >&2
fi
