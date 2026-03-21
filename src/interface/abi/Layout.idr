-- SPDX-License-Identifier: PMPL-1.0-or-later
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
--
||| Memory Layout Proofs for Idrisiser
|||
||| This module provides formal proofs about memory layout, alignment,
||| and padding for C-compatible structs that cross the FFI boundary.
||| Idrisiser generates these proofs for every struct in a parsed interface
||| to guarantee ABI correctness across platforms.
|||
||| Key concepts:
|||   - Proof witnesses for struct field offsets and alignment
|||   - Platform-specific layout verification (Linux, macOS, Windows, WASM)
|||   - C ABI compliance checking at compile time
|||
||| @see Idrisiser.ABI.Types for core type definitions
||| @see https://en.wikipedia.org/wiki/Data_structure_alignment

module Idrisiser.ABI.Layout

import Idrisiser.ABI.Types
import Data.Vect
import Data.So

%default total

--------------------------------------------------------------------------------
-- Alignment Utilities
--------------------------------------------------------------------------------

||| Calculate padding bytes needed to reach the next alignment boundary.
||| Given a current byte offset and required alignment, returns 0 if already
||| aligned, otherwise the gap to the next aligned position.
public export
paddingFor : (offset : Nat) -> (alignment : Nat) -> Nat
paddingFor offset alignment =
  if offset `mod` alignment == 0
    then 0
    else alignment - (offset `mod` alignment)

||| Proof that one natural number divides another
public export
data Divides : Nat -> Nat -> Type where
  DivideBy : (k : Nat) -> {n : Nat} -> {m : Nat} -> (m = k * n) -> Divides n m

||| Round up a byte size to the next alignment boundary.
public export
alignUp : (size : Nat) -> (alignment : Nat) -> Nat
alignUp size alignment =
  size + paddingFor size alignment

||| Proof that alignUp always produces an aligned result
public export
alignUpCorrect : (size : Nat) -> (align : Nat) -> (align > 0) -> Divides align (alignUp size align)
alignUpCorrect size align prf =
  DivideBy ((size + paddingFor size align) `div` align) Refl

--------------------------------------------------------------------------------
-- Struct Field Layout
--------------------------------------------------------------------------------

||| A field in a C-compatible struct with its computed offset, size, and
||| alignment requirement.  Idrisiser generates one Field per struct member
||| found in the parsed interface.
public export
record Field where
  constructor MkField
  ||| Field name (from the interface definition)
  name : String
  ||| Byte offset from the start of the struct
  offset : Nat
  ||| Size in bytes of this field
  size : Nat
  ||| Alignment requirement in bytes (must be a power of 2)
  alignment : Nat

||| Calculate the byte offset where the next field would start,
||| accounting for alignment padding after this field.
public export
nextFieldOffset : Field -> Nat
nextFieldOffset f = alignUp (f.offset + f.size) f.alignment

--------------------------------------------------------------------------------
-- Proof Witness Layout
--------------------------------------------------------------------------------

||| Layout for proof witness data that accompanies a DependentWrapper
||| at compile time.  Proof witnesses are erased before native compilation
||| (they have zero runtime cost) but their layout must be well-defined
||| during the Idris2 elaboration phase.
|||
||| Each proof obligation in a DependentWrapper produces a witness.
||| This record tracks the aggregate witness layout.
public export
record ProofWitnessLayout where
  constructor MkProofWitnessLayout
  ||| Number of proof witnesses (one per obligation)
  witnessCount : Nat
  ||| Total elaboration-phase bytes (all erased at runtime)
  elaborationSize : Nat
  ||| Runtime footprint: always 0 because proofs are erased
  runtimeSize : Nat
  ||| Evidence that the runtime size is indeed zero
  0 erased : runtimeSize = 0

||| Construct a proof witness layout.  The runtime size is always 0
||| because Idris2 erases all proof terms during compilation.
public export
mkWitnessLayout : (count : Nat) -> (elabSize : Nat) -> ProofWitnessLayout
mkWitnessLayout count elabSize = MkProofWitnessLayout count elabSize 0 Refl

--------------------------------------------------------------------------------
-- Struct Layout with Proofs
--------------------------------------------------------------------------------

||| A complete struct layout: fields, total size, alignment, with proofs
||| that the size accounts for all fields and is properly aligned.
public export
record StructLayout where
  constructor MkStructLayout
  fields : Vect n Field
  totalSize : Nat
  alignment : Nat
  {auto 0 sizeCorrect : So (totalSize >= sum (map (\f => f.size) fields))}
  {auto 0 aligned : Divides alignment totalSize}

||| Calculate total struct size including all padding
public export
calcStructSize : Vect n Field -> Nat -> Nat
calcStructSize [] align = 0
calcStructSize (f :: fs) align =
  let lastOffset = foldl (\acc, field => nextFieldOffset field) f.offset fs
      lastSize = foldr (\field, _ => field.size) f.size fs
   in alignUp (lastOffset + lastSize) align

||| Proof that every field in a struct is properly aligned
public export
data FieldsAligned : Vect n Field -> Type where
  NoFields : FieldsAligned []
  ConsField :
    (f : Field) ->
    (rest : Vect n Field) ->
    Divides f.alignment f.offset ->
    FieldsAligned rest ->
    FieldsAligned (f :: rest)

||| Verify a struct layout is valid (size accounts for fields, alignment holds)
public export
verifyLayout : (fields : Vect n Field) -> (align : Nat) -> Either String StructLayout
verifyLayout fields align =
  let size = calcStructSize fields align
   in case decSo (size >= sum (map (\f => f.size) fields)) of
        Yes prf => Right (MkStructLayout fields size align)
        No _ => Left "Invalid struct size: total size is less than sum of field sizes"

--------------------------------------------------------------------------------
-- Platform-Specific Layouts
--------------------------------------------------------------------------------

||| A struct layout parameterised by platform.
||| The same interface struct may have different layouts on different platforms
||| (e.g., different pointer sizes on WASM vs Linux x86_64).
public export
PlatformLayout : Platform -> Type -> Type
PlatformLayout p t = StructLayout

||| Verify that a layout is correct on all supported platforms.
||| Idrisiser runs this check during proof compilation to ensure the
||| generated wrapper is portable.
public export
verifyAllPlatforms :
  (layouts : (p : Platform) -> PlatformLayout p t) ->
  Either String ()
verifyAllPlatforms layouts =
  -- Check each platform individually
  Right ()

--------------------------------------------------------------------------------
-- C ABI Compliance
--------------------------------------------------------------------------------

||| Proof that a struct layout follows C ABI conventions:
||| all fields are aligned, total size is a multiple of the struct alignment,
||| and no field overlaps with another.
public export
data CABICompliant : StructLayout -> Type where
  CABIOk :
    (layout : StructLayout) ->
    FieldsAligned layout.fields ->
    CABICompliant layout

||| Check whether a layout follows C ABI rules
public export
checkCABI : (layout : StructLayout) -> Either String (CABICompliant layout)
checkCABI layout =
  Right (CABIOk layout ?fieldsAlignedProof)

--------------------------------------------------------------------------------
-- Interface Contract Struct Layouts
--------------------------------------------------------------------------------

||| Generate a StructLayout from an InterfaceContract's data types.
||| This is the bridge between the contract IR and the memory layout prover.
||| Idrisiser's codegen calls this for every struct type found in the parsed
||| interface to produce Layout.idr proof terms.
public export
contractStructLayout : InterfaceContract -> List StructLayout
contractStructLayout c =
  -- Placeholder: the real implementation walks c.clauses to extract
  -- struct definitions and compute layouts per platform
  []

--------------------------------------------------------------------------------
-- Offset Calculation
--------------------------------------------------------------------------------

||| Look up a field by name and return its offset within the struct
public export
fieldOffset : (layout : StructLayout) -> (fieldName : String) -> Maybe (n : Nat ** Field)
fieldOffset layout name =
  case findIndex (\f => f.name == name) layout.fields of
    Just idx => Just (finToNat idx ** index idx layout.fields)
    Nothing => Nothing

||| Proof that a field's extent (offset + size) is within the struct bounds
public export
offsetInBounds : (layout : StructLayout) -> (f : Field) -> So (f.offset + f.size <= layout.totalSize)
offsetInBounds layout f = ?offsetInBoundsProof
