-- SPDX-License-Identifier: MPL-2.0
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
--
||| Array-update invariants for Idrisiser (ABI Layer 3).
|||
||| Layer 2 (`Idrisiser.ABI.Semantics`) proved the *in-bounds totality* of the
||| generated accessor: an index is representable EXACTLY when it is `< n`, and
||| out-of-range reads are unrepresentable.  That is a property of READING.
|||
||| This module proves a genuinely DEEPER and DISTINCT class of property: the
||| algebraic LAWS that relate a generated WRITE to a subsequent READ — the
||| "memory model" correctness of the wrapper Idrisiser emits.  These are the
||| canonical store/select axioms of McCarthy's theory of arrays:
|||
|||   * WRITE-THEN-READ (read-over-write, same index):
|||       reading slot `i` immediately after writing `v` into slot `i`
|||       returns exactly `v`.            `safeReadAfterWriteSame`
|||
|||   * READ-OTHER (read-over-write, different index):
|||       a write at slot `j` leaves every OTHER slot `i /= j` untouched.
|||       `safeReadAfterWriteOther`
|||
|||   * DECISIVE READ-OVER-WRITE: a single, sound decision procedure on the two
|||     indices that returns the value a post-write read must yield, together
|||     with a proof it is correct.  `safeReadOverWrite`
|||
||| Everything is built over the SAME model exported by Layer 2 — the same
||| `SafeArray`, the same `safeIndex` — so the two layers compose.  The new
||| accessor `safeWrite` is the formal dual of `safeIndex`.  The Vect-level
||| lemmas are proved here by hand (induction on the index / vector), NOT
||| delegated to a library lemma, so this is a self-contained genuine proof.
|||
||| Controls: a POSITIVE witness that a concrete write-then-read returns the
||| written element, a POSITIVE witness that a neighbouring slot is preserved,
||| and a NEGATIVE / non-vacuity control (`Not (... = oldValue)`) showing the
||| write genuinely changed the slot — machine-checked.

module Idrisiser.ABI.Invariants

import Idrisiser.ABI.Semantics
import Data.Fin
import Data.Vect
import Decidable.Equality

%default total

--------------------------------------------------------------------------------
-- 1. The write accessor: formal dual of Layer 2's `safeIndex`
--------------------------------------------------------------------------------

||| Write `v` into slot `i` of a length-indexed buffer.  Like `safeIndex`, it
||| takes a *proven* index `Fin n`, so there is no error path and the length is
||| preserved in the TYPE: a write can never resize or escape the buffer.  This
||| is the store half of the generated read/write pair.
public export
safeWrite : SafeArray n a -> Fin n -> a -> SafeArray n a
safeWrite (MkSafeArray xs) i v = MkSafeArray (replaceAt i v xs)

--------------------------------------------------------------------------------
-- 2. Vect-level lemmas (proved by hand here)
--------------------------------------------------------------------------------

||| WRITE-THEN-READ at the Vect level: after replacing slot `i` with `v`,
||| reading slot `i` yields `v`.  Proved by induction on the index, mirroring
||| the recursive structure of both `index` and `replaceAt`.
export
indexReplaceAtSame : (i : Fin n) -> (v : a) -> (xs : Vect n a) ->
                     index i (replaceAt i v xs) = v
indexReplaceAtSame FZ     v (_ :: _)  = Refl
indexReplaceAtSame (FS k) v (_ :: ys) = indexReplaceAtSame k v ys

||| READ-OTHER at the Vect level: a write at slot `j` does not disturb a
||| DIFFERENT slot `i /= j`.  Proved by induction on both indices; the two
||| `FZ`/`FS` cross cases are immediate, the `FS`/`FS` case recurses with the
||| tail-level distinctness derived from injectivity of `FS`.
export
indexReplaceAtOther : (i, j : Fin n) -> Not (i = j) -> (v : a) ->
                      (xs : Vect n a) ->
                      index i (replaceAt j v xs) = index i xs
indexReplaceAtOther FZ     FZ     neq _ (_ :: _)  = absurd (neq Refl)
indexReplaceAtOther FZ     (FS _) _   _ (_ :: _)  = Refl
indexReplaceAtOther (FS _) FZ     _   _ (_ :: _)  = Refl
indexReplaceAtOther (FS k) (FS m) neq v (_ :: ys) =
  indexReplaceAtOther k m (\eq => neq (cong FS eq)) v ys

--------------------------------------------------------------------------------
-- 3. The Layer-3 laws, lifted to the SafeArray model
--------------------------------------------------------------------------------

||| WRITE-THEN-READ LAW (read-over-write, same index): reading slot `i` of the
||| array produced by writing `v` into slot `i` returns exactly `v`.  This is
||| the store/select axiom for matching indices.
public export
safeReadAfterWriteSame : (arr : SafeArray n a) -> (i : Fin n) -> (v : a) ->
                         safeIndex (safeWrite arr i v) i = v
safeReadAfterWriteSame (MkSafeArray xs) i v = indexReplaceAtSame i v xs

||| READ-OTHER LAW (read-over-write, different index): writing `v` into slot `j`
||| leaves every other slot `i /= j` exactly as it was.  This is the locality /
||| non-interference axiom that makes the generated buffer a real array.
public export
safeReadAfterWriteOther : (arr : SafeArray n a) -> (i, j : Fin n) ->
                          Not (i = j) -> (v : a) ->
                          safeIndex (safeWrite arr j v) i = safeIndex arr i
safeReadAfterWriteOther (MkSafeArray xs) i j neq v =
  indexReplaceAtOther i j neq v xs

--------------------------------------------------------------------------------
-- 4. Decisive read-over-write: sound decision procedure
--------------------------------------------------------------------------------

||| The value a post-write read MUST return, decided on the two indices.
|||
||| `decEq` on `Fin n` is the natural, sound+complete decision here.  When the
||| indices coincide we know (by the write-then-read law) the result is the
||| written value; when they differ we know (by the read-other law) the result
||| is the original element.  `safeReadOverWriteCorrect` proves this dispatch
||| agrees with the actual accessor on the actual array — no case is guessed.
public export
predictReadOverWrite : (arr : SafeArray n a) -> (i, j : Fin n) -> (v : a) -> a
predictReadOverWrite arr i j v = case decEq i j of
  Yes _ => v
  No  _ => safeIndex arr i

||| SOUNDNESS of the prediction: an actual read after the actual write equals
||| the predicted value, in BOTH branches of the decision.
public export
safeReadOverWriteCorrect : (arr : SafeArray n a) -> (i, j : Fin n) -> (v : a) ->
                           safeIndex (safeWrite arr j v) i =
                           predictReadOverWrite arr i j v
safeReadOverWriteCorrect arr i j v with (decEq i j)
  safeReadOverWriteCorrect arr i j v | Yes eq =
    -- i = j, so a read at i is a read at the slot just written.
    rewrite eq in safeReadAfterWriteSame arr j v
  safeReadOverWriteCorrect arr i j v | No neq =
    safeReadAfterWriteOther arr i j neq v

--------------------------------------------------------------------------------
-- 5. Controls
--------------------------------------------------------------------------------

||| A concrete 3-element array used by the controls (independent of the Layer-2
||| `demoArray` so the controls here stand alone).
public export
ctrlArray : SafeArray 3 String
ctrlArray = MkSafeArray ["alpha", "beta", "gamma"]

||| POSITIVE control (write-then-read): writing "delta" into slot 1 and reading
||| slot 1 back returns "delta".  Concrete, so it reduces by `Refl`.
public export
writeThenReadDelta : safeIndex (safeWrite Invariants.ctrlArray 1 "delta") 1 = "delta"
writeThenReadDelta = Refl

||| POSITIVE control (read-other): writing "delta" into slot 1 leaves slot 0
||| ("alpha") untouched.  Concrete, reduces by `Refl`.
public export
otherSlotPreserved : safeIndex (safeWrite Invariants.ctrlArray 1 "delta") 0 = "alpha"
otherSlotPreserved = Refl

||| POSITIVE control (decision agrees): the predictor for a same-index read
||| returns the written value "delta".  Reduces by `Refl`.
public export
predictionAtSameSlot : predictReadOverWrite Invariants.ctrlArray 1 1 "delta" = "delta"
predictionAtSameSlot = Refl

||| NEGATIVE / non-vacuity control: the write GENUINELY changed slot 1 — after
||| writing "delta", slot 1 is NOT the old value "beta".  Were the laws vacuous
||| or `safeWrite` a no-op, this refutation would be unprovable.  Machine-checked
||| via `safeReadAfterWriteSame` (slot 1 reads "delta") and the concrete fact
||| that "delta" /= "beta".
public export
writeReallyChangedSlot :
  Not (safeIndex (safeWrite Invariants.ctrlArray 1 "delta") 1 = "beta")
writeReallyChangedSlot eq =
  -- The accessor reads "delta" (law); chaining gives "delta" = "beta", absurd.
  case trans (sym (safeReadAfterWriteSame Invariants.ctrlArray 1 "delta")) eq of
    Refl impossible
