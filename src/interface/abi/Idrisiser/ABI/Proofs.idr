-- SPDX-License-Identifier: MPL-2.0
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
--
||| Machine-checked proofs over the idrisiser ABI.
|||
||| These are not runtime tests — they are propositional statements the Idris2
||| type checker must discharge at compile time. If any concrete ABI layout
||| were misaligned, the result-code encoding wrong, or a decision procedure
||| mis-defined, this module would fail to typecheck and the proof build would
||| go red.
|||
||| The C-ABI compliance witnesses are built directly from per-field
||| divisibility proofs (`DivideBy k Refl`, where `offset = k * alignment`).
||| Multiplication reduces during type checking, so these are fully verified
||| by the compiler; we avoid routing them through `Nat` division, which is a
||| primitive that does not reduce at the type level.

module Idrisiser.ABI.Proofs

import Idrisiser.ABI.Types
import Idrisiser.ABI.Layout
import Data.So
import Data.Vect

%default total

--------------------------------------------------------------------------------
-- The concrete FFI struct layouts are provably C-ABI compliant.
--------------------------------------------------------------------------------

||| Every field offset in the proof-engine context layout divides its
||| alignment: 0|8, 8|8, 16|4, 20|4, 24|8, 32|4, 36|4, 40|8.
export
proofEngineContextCompliant : CABICompliant Layout.proofEngineContextLayout
proofEngineContextCompliant =
  CABIOk proofEngineContextLayout
    (ConsField _ _ (DivideBy 0 Refl)
    (ConsField _ _ (DivideBy 1 Refl)
    (ConsField _ _ (DivideBy 4 Refl)
    (ConsField _ _ (DivideBy 5 Refl)
    (ConsField _ _ (DivideBy 3 Refl)
    (ConsField _ _ (DivideBy 8 Refl)
    (ConsField _ _ (DivideBy 9 Refl)
    (ConsField _ _ (DivideBy 5 Refl)
     NoFields))))))))

||| Every field offset in the proof-obligation layout is aligned:
||| 0|8, 8|4, 12|4, 16|8, 24|4, 28|4.
export
proofObligationCompliant : CABICompliant Layout.proofObligationLayout
proofObligationCompliant =
  CABIOk proofObligationLayout
    (ConsField _ _ (DivideBy 0 Refl)
    (ConsField _ _ (DivideBy 2 Refl)
    (ConsField _ _ (DivideBy 3 Refl)
    (ConsField _ _ (DivideBy 2 Refl)
    (ConsField _ _ (DivideBy 6 Refl)
    (ConsField _ _ (DivideBy 7 Refl)
     NoFields))))))

||| Every field offset in the handle-data layout is aligned: 0|8, 8|4, 12|4.
export
handleDataCompliant : CABICompliant Layout.handleDataLayout
handleDataCompliant =
  CABIOk handleDataLayout
    (ConsField _ _ (DivideBy 0 Refl)
    (ConsField _ _ (DivideBy 2 Refl)
    (ConsField _ _ (DivideBy 3 Refl)
     NoFields)))

--------------------------------------------------------------------------------
-- Result-code encoding: the contract the Zig FFI depends on.
--------------------------------------------------------------------------------

||| Success encodes as 0 — the FFI success sentinel.
export
okIsZero : resultToInt Ok = 0
okIsZero = Refl

||| The proof-failure code encodes as 5, the highest result code.
export
proofFailureIsFive : resultToInt ProofFailure = 5
proofFailureIsFive = Refl

||| Distinct result codes encode to distinct integers (Ok vs NullPointer),
||| so the Zig side can disambiguate them.
export
okNotNullPointer : Not (resultToInt Ok = resultToInt NullPointer)
okNotNullPointer = \case Refl impossible
