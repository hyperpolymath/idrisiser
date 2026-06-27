-- SPDX-License-Identifier: MPL-2.0
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
--
||| Flagship semantic proof for Idrisiser (ABI Layer 2).
|||
||| Idrisiser's headline promise is to "generate proven-correct wrappers using
||| Idris2 dependent types".  The canonical such wrapper is a *bounded array
||| accessor*: a generated function that reads element `i` of an `n`-element
||| array and is GUARANTEED never to read out of bounds at runtime.
|||
||| This module gives that promise a real, machine-checked meaning:
|||
|||   1. A faithful model of a length-indexed array (`SafeArray n a` wrapping a
|||      `Vect n a`) and its total accessor `safeIndex : SafeArray n a -> Fin n
|||      -> a`.
|||   2. The headline property `InBounds i n` — inhabited EXACTLY when `i < n`
|||      (it carries an `LT i n` proof).  The out-of-range case has no
|||      constructor, and in particular NO index exists into an empty array
|||      (`Uninhabited (InBounds i 0)`): out-of-range access is unrepresentable.
|||   3. A sound AND complete decision procedure `decInBounds` returning a real
|||      `Dec (InBounds i n)`, backed by `Data.Nat.isLT`.
|||   4. A totality / no-off-by-one fact: the proven index round-trips exactly to
|||      the requested raw position (`finToNat (toFin ok) = i`), via the
|||      hand-proved `finToNatNatToFinLT`.  `safeIndex` is total — no error code,
|||      no partiality.
|||   5. A certifier into the ABI's `Totality` witness with a soundness proof
|||      (`certifyBounded` returns `Total` only when the index is genuinely in
|||      bounds).
|||   6. A POSITIVE control (an inhabited witness that reads the expected
|||      element) and NEGATIVE controls (`Not (InBounds 5 3)` and the empty
|||      array), all machine-checked.

module Idrisiser.ABI.Semantics

import Idrisiser.ABI.Types
import Data.Fin
import Data.Nat
import Data.Vect
import Decidable.Equality

%default total

--------------------------------------------------------------------------------
-- 1. Faithful model
--------------------------------------------------------------------------------

||| A generated bounded-array wrapper: a length-indexed buffer.  The length `n`
||| is part of the TYPE, so it cannot drift from the data at runtime.
public export
record SafeArray (n : Nat) (a : Type) where
  constructor MkSafeArray
  buffer : Vect n a

||| The total, never-failing accessor that Idrisiser's codegen emits.  It takes
||| a *proven* index `Fin n`; there is no error path and no partiality, so the
||| result is always a genuine element of the array.
public export
safeIndex : SafeArray n a -> Fin n -> a
safeIndex (MkSafeArray xs) i = index i xs

--------------------------------------------------------------------------------
-- 2. The headline property: InBounds
--------------------------------------------------------------------------------

||| `InBounds i n` is inhabited exactly when the raw natural index `i` is a
||| legal index into an `n`-element array, i.e. `i < n`.  The witness carries an
||| `LT i n` proof, from which a real `Fin n` safe index is computed.
|||
||| There is deliberately no constructor for the out-of-range case: when
||| `i >= n` there is no `LT i n`, so `InBounds i n` cannot be built.
public export
data InBounds : (i : Nat) -> (n : Nat) -> Type where
  MkInBounds : (prf : LT i n) -> InBounds i n

||| Compute the proven safe index from an in-bounds witness.
public export
toFin : {i, n : Nat} -> InBounds i n -> Fin n
toFin (MkInBounds prf) = natToFinLT i {prf}

||| There is NO index at all into an empty array, so any claim that some `i` is
||| in bounds of a 0-length array is absurd.  This is the formal statement that
||| out-of-range access is unrepresentable in the model.
public export
Uninhabited (InBounds i 0) where
  uninhabited (MkInBounds prf) = absurd prf

--------------------------------------------------------------------------------
-- 3. Sound + complete decision procedure
--------------------------------------------------------------------------------

||| Decide whether raw index `i` is in bounds of an `n`-element array.
|||
||| SOUND:    a `Yes` carries a genuine `LT i n` proof.
||| COMPLETE: a `No` is a real refutation — any `InBounds i n` would yield the
|||           very `LT i n` that `isLT` has just shown impossible.
public export
decInBounds : (i : Nat) -> (n : Nat) -> Dec (InBounds i n)
decInBounds i n = case isLT i n of
  Yes prf   => Yes (MkInBounds prf)
  No  contra => No (\(MkInBounds prf) => contra prf)

--------------------------------------------------------------------------------
-- 4. Totality / no-off-by-one fact
--------------------------------------------------------------------------------

||| The proven index lands exactly on the requested raw position: converting an
||| `LT i n` proof to a `Fin n` and back to a `Nat` returns `i`.  Proved by
||| induction on the `LT` witness — no `believe_me`, no `assert`.
public export
finToNatNatToFinLT : (i : Nat) -> (prf : LT i n) ->
                     finToNat (natToFinLT i {prf}) = i
finToNatNatToFinLT Z     (LTESucc _) = Refl
finToNatNatToFinLT (S k) (LTESucc p) = cong S (finToNatNatToFinLT k p)

||| For any proven index into any array, the index the accessor uses round-trips
||| back to the requested raw position `i`.  This is the "no off-by-one, no
||| runtime failure" guarantee: `safeIndex` reads precisely slot `i`.
public export
safeIndexUsesExactSlot : {i, n : Nat} -> (arr : SafeArray n a) ->
                         (ok : InBounds i n) -> finToNat (toFin ok) = i
safeIndexUsesExactSlot arr (MkInBounds prf) = finToNatNatToFinLT i prf

--------------------------------------------------------------------------------
-- 5. Certifier into the ABI Totality witness
--------------------------------------------------------------------------------

||| Certify a candidate (raw index, length) pair: `Total` when the generated
||| accessor is provably never-failing for that index, `Covering` otherwise.
public export
certifyBounded : (i : Nat) -> (n : Nat) -> Totality
certifyBounded i n = case decInBounds i n of
  Yes _ => Total
  No  _ => Covering

||| Soundness of the certifier: it returns `Total` only when the index really
||| is in bounds (so the generated wrapper really is failure-free).
public export
certifyBoundedSound : (i : Nat) -> (n : Nat) ->
                      certifyBounded i n = Total -> InBounds i n
certifyBoundedSound i n eq with (decInBounds i n)
  certifyBoundedSound i n eq   | Yes ok = ok
  certifyBoundedSound i n Refl | No  _ impossible

--------------------------------------------------------------------------------
-- 6. Controls
--------------------------------------------------------------------------------

||| A concrete 3-element array used by the controls.
public export
demoArray : SafeArray 3 String
demoArray = MkSafeArray ["alpha", "beta", "gamma"]

||| POSITIVE control: index 2 is in bounds of a 3-element array (explicit,
||| inhabited witness carrying a real `LT 2 3` proof).
public export
idx2InBounds : InBounds 2 3
idx2InBounds = MkInBounds (LTESucc (LTESucc (LTESucc LTEZero)))

||| The positive control actually reads the expected element through the total
||| accessor.  Concrete, so it reduces by `Refl`.
public export
demoReadsGamma : safeIndex Semantics.demoArray (toFin Semantics.idx2InBounds) = "gamma"
demoReadsGamma = Refl

||| The positive control's proven index round-trips to raw position 2.
public export
idx2RoundTrips : finToNat (toFin Semantics.idx2InBounds) = 2
idx2RoundTrips = Refl

||| NEGATIVE control: index 5 is NOT in bounds of a 3-element array — a
||| machine-checked refutation of the bad case (no `LT 5 3` exists).
public export
idx5OutOfBounds : Not (InBounds 5 3)
idx5OutOfBounds (MkInBounds prf) = absurd prf

||| NEGATIVE control: there is no index at all into an empty array.
public export
noIndexIntoEmpty : Not (InBounds i 0)
noIndexIntoEmpty = absurd
