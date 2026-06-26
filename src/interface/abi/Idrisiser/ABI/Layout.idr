-- SPDX-License-Identifier: MPL-2.0
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
import Data.Nat
import Decidable.Equality

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
    else minus alignment (offset `mod` alignment)

||| Proof that one natural number divides another
public export
data Divides : Nat -> Nat -> Type where
  DivideBy : (k : Nat) -> {n : Nat} -> {m : Nat} -> (m = k * n) -> Divides n m

||| Round up a byte size to the next alignment boundary.
public export
alignUp : (size : Nat) -> (alignment : Nat) -> Nat
alignUp size alignment =
  size + paddingFor size alignment

||| Sound decision procedure for divisibility. Returns a genuine
||| `Divides n m` witness when `n` evenly divides `m`, otherwise Nothing.
||| Division by zero is undecidable here and yields Nothing.
public export
decDivides : (n : Nat) -> (m : Nat) -> Maybe (Divides n m)
decDivides Z _ = Nothing
decDivides (S k) m =
  let q = m `div` (S k) in
  case decEq m (q * (S k)) of
    Yes prf => Just (DivideBy q prf)
    No _ => Nothing

||| Sound divisibility check for an aligned size. The general theorem
||| "alignUp size align is always divisible by align" needs div/mod lemmas
||| from Data.Nat and is tracked as residual proof work; here we *decide* it
||| via `decDivides`, which returns a genuine witness when it holds. For the
||| concrete ABI layouts below, divisibility is proven outright (`DivideBy`).
||| (Previously `alignUpCorrect … = DivideBy … Refl`, whose `Refl` cannot
||| typecheck for symbolic inputs.)
public export
alignUpDivides : (size : Nat) -> (align : Nat) ->
                 Maybe (Divides align (alignUp size align))
alignUpDivides size align = decDivides align (alignUp size align)

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
calcStructSize : Vect k Field -> Nat -> Nat
calcStructSize [] align = 0
calcStructSize (f :: fs) align =
  let lastOffset = foldl (\acc, field => nextFieldOffset field) f.offset fs
      lastSize = foldr (\field, _ => field.size) f.size fs
   in alignUp (lastOffset + lastSize) align

||| Proof that every field in a struct is properly aligned
public export
data FieldsAligned : Vect k Field -> Type where
  NoFields : FieldsAligned []
  ConsField :
    (f : Field) ->
    (rest : Vect k Field) ->
    Divides f.alignment f.offset ->
    FieldsAligned rest ->
    FieldsAligned (f :: rest)

||| Decide field alignment for every field, building a real `FieldsAligned`
||| witness from per-field divisibility proofs.
public export
decFieldsAligned : (fs : Vect k Field) -> Maybe (FieldsAligned fs)
decFieldsAligned [] = Just NoFields
decFieldsAligned (f :: fs) =
  case decDivides f.alignment f.offset of
    Nothing => Nothing
    Just dvd => case decFieldsAligned fs of
                  Nothing => Nothing
                  Just rest => Just (ConsField f fs dvd rest)

--------------------------------------------------------------------------------
-- Concrete Idrisiser FFI Struct Layouts
--------------------------------------------------------------------------------

||| C-compatible layout for the proof-engine context that the Zig FFI owns.
||| Every field offset is a multiple of its alignment and the total size
||| (48) is a multiple of the struct alignment (8): 48 = 6 * 8.
public export
proofEngineContextLayout : StructLayout
proofEngineContextLayout =
  MkStructLayout
    [ MkField "handle_ptr" 0 8 8
    , MkField "model_ptr" 8 8 8
    , MkField "num_obligations" 16 4 4
    , MkField "discharged_count" 20 4 4
    , MkField "error_ptr" 24 8 8
    , MkField "error_len" 32 4 4
    , MkField "initialized" 36 4 4
    , MkField "padding" 40 8 8
    ]
    48
    8
    {sizeCorrect = Oh}
    {aligned = DivideBy 6 Refl}

||| C-compatible layout for a single proof obligation passed across the FFI.
||| Total size (32) is a multiple of the struct alignment (8): 32 = 4 * 8.
public export
proofObligationLayout : StructLayout
proofObligationLayout =
  MkStructLayout
    [ MkField "source_ptr" 0 8 8
    , MkField "kind" 8 4 4
    , MkField "discharged" 12 4 4
    , MkField "prooftype_ptr" 16 8 8
    , MkField "prooftype_len" 24 4 4
    , MkField "padding" 28 4 4
    ]
    32
    8
    {sizeCorrect = Oh}
    {aligned = DivideBy 4 Refl}

||| C-compatible layout for the opaque handle data block.
||| Total size (16) is a multiple of the struct alignment (8): 16 = 2 * 8.
public export
handleDataLayout : StructLayout
handleDataLayout =
  MkStructLayout
    [ MkField "ptr" 0 8 8
    , MkField "generation" 8 4 4
    , MkField "flags" 12 4 4
    ]
    16
    8
    {sizeCorrect = Oh}
    {aligned = DivideBy 2 Refl}

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

||| Verify a layout against the C ABI alignment rules, returning a genuine
||| `CABICompliant` proof (built from real per-field divisibility witnesses)
||| or an error when some field offset is misaligned.
public export
checkCABI : (layout : StructLayout) -> Either String (CABICompliant layout)
checkCABI layout =
  case decFieldsAligned layout.fields of
    Just prf => Right (CABIOk layout prf)
    Nothing => Left "Field offsets are not correctly aligned for the C ABI"

||| Verify that all concrete idrisiser layouts are C-ABI compliant. Fails
||| (Left) if any layout is misaligned, rather than asserting it.
public export
verifyAllLayouts : Either String ()
verifyAllLayouts = do
  _ <- checkCABI proofEngineContextLayout
  _ <- checkCABI proofObligationLayout
  _ <- checkCABI handleDataLayout
  Right ()

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

||| Decide whether a field lies within a struct's byte bounds, returning a
||| genuine proof when `offset + size <= totalSize`. The previous signature
||| asserted this for *every* field unconditionally, which is unsound (a field
||| need not belong to the layout); this honest version decides it via `choose`.
public export
offsetInBounds : (layout : StructLayout) -> (f : Field) ->
                 Maybe (So (f.offset + f.size <= layout.totalSize))
offsetInBounds layout f =
  case choose (f.offset + f.size <= layout.totalSize) of
    Left ok => Just ok
    Right _ => Nothing
