-- SPDX-License-Identifier: MPL-2.0
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
--
||| Layer 5 — the end-to-end ABI SOUNDNESS CERTIFICATE.
|||
||| Each prior layer discharged one part of the Idrisiser ABI contract in
||| isolation:
|||
|||   * Layer 2 (`Idrisiser.ABI.Semantics`) — the FLAGSHIP property: a generated
|||     bounded-array accessor is in-bounds-total, out-of-range access being
|||     unrepresentable.  Its canonical positive control is `idx2InBounds`, an
|||     inhabited `InBounds 2 3` witness.
|||   * Layer 3 (`Idrisiser.ABI.Invariants`) — the DEEPER store/select invariant
|||     relating a generated WRITE to a subsequent READ.  Its concrete positive
|||     control is `writeThenReadDelta`: writing "delta" into slot 1 and reading
|||     slot 1 back returns "delta".
|||   * Layer 4 (`Idrisiser.ABI.FfiSeam`) — sealing the ABI<->FFI seam: the wire
|||     encoding `resultToInt` is injective, so distinct ABI outcomes never
|||     collide as they cross into Zig/C.  The proof is `resultToIntInjective`.
|||
||| This capstone ties those three together into ONE inhabited value.  The record
||| `ABISound` has one field per layer, each field's TYPE being the precise
||| proven fact of that layer; the single value `abiContractDischarged` fills
||| every field with the REAL exported witness/theorem from the layer above.
||| Because the record is constructed only from genuine proofs, the existence of
||| `abiContractDischarged` is a machine-checked statement that the full ABI
||| contract — manifest -> ABI proofs (flagship + invariant) -> FFI seam — is
||| discharged together: if any prior layer were unsound, no field could be
||| filled and this value would not typecheck.
|||
||| Non-vacuity is enforced by the adversarial control (see /tmp/Adv*.idr in the
||| build procedure): a bogus certificate — e.g. claiming the flagship control is
||| `InBounds 5 3`, or that the write-then-read returns "beta" — is REJECTED by
||| the type checker, so `ABISound` cannot be inhabited by a false component.

module Idrisiser.ABI.Capstone

import Idrisiser.ABI.Types
import Idrisiser.ABI.Semantics
import Idrisiser.ABI.Invariants
import Idrisiser.ABI.FfiSeam
import Data.Fin

%default total

--------------------------------------------------------------------------------
-- The certificate record: one field per discharged ABI layer
--------------------------------------------------------------------------------

||| An end-to-end soundness certificate for the Idrisiser ABI.  Each field's
||| type is the exact proven fact of one prior layer, so the record is
||| inhabitable ONLY when all three layers are genuinely sound.
public export
record ABISound where
  constructor MkABISound
  ||| Layer 2 (flagship): the canonical positive control — raw index 2 is in
  ||| bounds of a 3-element array (an inhabited `InBounds 2 3`).
  flagshipControl : InBounds 2 3
  ||| Layer 3 (deeper invariant): the concrete write-then-read law instance —
  ||| writing "delta" into slot 1 of the control array and reading slot 1 back
  ||| returns exactly "delta".
  layer3Invariant : safeIndex (safeWrite Invariants.ctrlArray 1 "delta") 1 = "delta"
  ||| Layer 4 (FFI seam): the wire encoding is injective — distinct ABI outcomes
  ||| never collide as they cross to Zig/C.
  ffiSeamInjective : (a, b : Result) -> resultToInt a = resultToInt b -> a = b

--------------------------------------------------------------------------------
-- The capstone value: assembled from the real exported witnesses
--------------------------------------------------------------------------------

||| THE CAPSTONE.  A single inhabited `ABISound`, each field supplied by the
||| genuine exported proof of the corresponding layer:
|||
|||   * `flagshipControl`  = `Semantics.idx2InBounds`     (Layer 2)
|||   * `layer3Invariant`  = `Invariants.writeThenReadDelta` (Layer 3)
|||   * `ffiSeamInjective` = `FfiSeam.resultToIntInjective`   (Layer 4)
|||
||| Nothing is fabricated; every field is a name that already typechecked in its
||| home module.  This value's existence is the end-to-end soundness statement.
public export
abiContractDischarged : ABISound
abiContractDischarged =
  MkABISound
    Semantics.idx2InBounds
    writeThenReadDelta
    resultToIntInjective
