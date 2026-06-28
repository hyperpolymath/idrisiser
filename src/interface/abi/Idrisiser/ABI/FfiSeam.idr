-- SPDX-License-Identifier: MPL-2.0
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
--
||| Layer 4 — Sealing the ABI<->FFI seam.
|||
||| The structural gate (scripts/abi-ffi-gate.py) checks that the Idris2 and
||| Zig result-code enums agree by name and value. This module supplies the
||| PROOF-SIDE guarantee that the encoding `resultToInt : Result -> Bits32`
||| is SOUND:
|||
|||   * distinct ABI outcomes never collide on the wire (injectivity), and
|||   * the C integer faithfully round-trips back to the ABI value
|||     (a total decoder `intToResult` with `intToResult (resultToInt r) = Just r`).
|||
||| Injectivity is DERIVED from the round-trip (the cleanest route): if
||| `resultToInt a = resultToInt b` then applying `intToResult` to both sides
||| (via `cong`) and using the round-trip identities forces `Just a = Just b`,
||| whence `a = b` by injectivity of `Just`.
|||
||| The decoder is built with boolean `Bits32` `==` (which reduces on concrete
||| literals) so the round-trip proofs discharge by `Refl`.

module Idrisiser.ABI.FfiSeam

import Idrisiser.ABI.Types

%default total

--------------------------------------------------------------------------------
-- Local helper: Just is injective
--------------------------------------------------------------------------------

||| `Just` is injective. Proved locally to avoid depending on a particular
||| base-library name; the single `Refl` clause forces the two payloads equal.
private
justInj : {0 x, y : a} -> Just x = Just y -> x = y
justInj Refl = Refl

--------------------------------------------------------------------------------
-- Decoder: C integer -> ABI Result
--------------------------------------------------------------------------------

||| Decode a C result code back into the ABI `Result`.
|||
||| Built with chained boolean `==` on `Bits32` rather than literal
||| pattern-matching: `==` reduces definitionally on concrete constants, so the
||| round-trip lemmas below check by `Refl`. Any integer outside the known
||| range decodes to `Nothing` (faithful: the encoder is not surjective).
public export
intToResult : Bits32 -> Maybe Result
intToResult x =
  if x == 0 then Just Ok
  else if x == 1 then Just Error
  else if x == 2 then Just InvalidParam
  else if x == 3 then Just OutOfMemory
  else if x == 4 then Just NullPointer
  else if x == 5 then Just ProofFailure
  else Nothing

--------------------------------------------------------------------------------
-- (b) Faithful / lossless round-trip
--------------------------------------------------------------------------------

||| Encoding then decoding recovers the original ABI value: the C integer is a
||| faithful representation of every `Result`. Each clause reduces because the
||| corresponding `==` test on the concrete literal evaluates to `True`.
export
resultRoundTrip : (r : Result) -> intToResult (resultToInt r) = Just r
resultRoundTrip Ok           = Refl
resultRoundTrip Error        = Refl
resultRoundTrip InvalidParam = Refl
resultRoundTrip OutOfMemory  = Refl
resultRoundTrip NullPointer  = Refl
resultRoundTrip ProofFailure = Refl

--------------------------------------------------------------------------------
-- (a) Injectivity, derived from the round-trip
--------------------------------------------------------------------------------

||| The encoding is unambiguous: distinct outcomes never collide on the wire.
||| Derived from `resultRoundTrip` — no case explosion, no `believe_me`.
|||
||| Given `resultToInt a = resultToInt b`, `cong intToResult` yields
||| `intToResult (resultToInt a) = intToResult (resultToInt b)`; rewriting both
||| ends by the round-trip gives `Just a = Just b`, and injectivity of `Just`
||| strips the constructor.
export
resultToIntInjective : (a, b : Result)
                    -> resultToInt a = resultToInt b
                    -> a = b
resultToIntInjective a b prf =
  justInj $
    rewrite sym (resultRoundTrip a) in
    rewrite sym (resultRoundTrip b) in
    cong intToResult prf

--------------------------------------------------------------------------------
-- Positive controls (concrete decodes, machine-checked)
--------------------------------------------------------------------------------

||| Decoding 0 yields Ok.
decodeZeroIsOk : intToResult 0 = Just Ok
decodeZeroIsOk = Refl

||| Decoding 5 yields ProofFailure (the top of the range).
decodeFiveIsProofFailure : intToResult 5 = Just ProofFailure
decodeFiveIsProofFailure = Refl

||| Decoding an out-of-range code yields Nothing (encoder is not surjective).
decodeOutOfRangeIsNothing : intToResult 99 = Nothing
decodeOutOfRangeIsNothing = Refl

||| Round-trip control for a specific value.
roundTripOk : intToResult (resultToInt Ok) = Just Ok
roundTripOk = Refl

--------------------------------------------------------------------------------
-- Negative / non-vacuity control
--------------------------------------------------------------------------------

||| Two DISTINCT result codes have DISTINCT wire integers. This rules out the
||| vacuous reading of injectivity: the encoding genuinely separates outcomes.
||| `0 = 1` on `Bits32` is refuted by the coverage checker on distinct
||| primitive constants.
export
okWireDistinctFromError : Not (resultToInt Ok = resultToInt Error)
okWireDistinctFromError = \case Refl impossible

||| A second non-vacuity witness across a non-adjacent pair.
export
okWireDistinctFromProofFailure : Not (resultToInt Ok = resultToInt ProofFailure)
okWireDistinctFromProofFailure = \case Refl impossible
