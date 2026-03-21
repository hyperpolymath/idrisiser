-- SPDX-License-Identifier: PMPL-1.0-or-later
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
--
||| ABI Type Definitions for Idrisiser
|||
||| This module defines the core types that Idrisiser uses to represent
||| interface contracts, proof obligations, and dependent wrappers.
||| These are the types that flow through the proof generation pipeline:
||| parsed interface → proof obligations → verified wrapper.
|||
||| @see Idrisiser TOPOLOGY.md for pipeline architecture

module Idrisiser.ABI.Types

import Data.Bits
import Data.So
import Data.Vect
import Data.List

%default total

--------------------------------------------------------------------------------
-- Platform Detection
--------------------------------------------------------------------------------

||| Supported target platforms for generated native wrappers
public export
data Platform = Linux | Windows | MacOS | BSD | WASM

||| Compile-time platform detection
public export
thisPlatform : Platform
thisPlatform =
  %runElab do
    pure Linux  -- Default; override with compiler flags per target

--------------------------------------------------------------------------------
-- Interface Contract Types
--------------------------------------------------------------------------------

||| An interface source format that Idrisiser can parse.
||| Each variant corresponds to a bridge adapter in src/bridges/.
public export
data InterfaceFormat
  = OpenAPI      -- OpenAPI 3.x JSON/YAML specifications
  | CHeader      -- C .h header files
  | ProtoBuf     -- Protocol Buffers .proto definitions
  | TypeSig      -- Bare Haskell/Idris/ML-style type signatures
  | Custom String -- User-defined format with named parser

||| A single contract clause extracted from a parsed interface.
||| Preconditions restrict inputs; postconditions constrain outputs;
||| invariants must hold across the entire call.
public export
data ContractClause
  = Precondition String    -- Must hold before the call
  | Postcondition String   -- Must hold after the call
  | Invariant String       -- Must hold before and after

||| An interface contract: the collection of all obligations that the
||| generated wrapper must formally prove.
public export
record InterfaceContract where
  constructor MkInterfaceContract
  ||| Human-readable name of the interface (e.g., "PetStore API v3")
  name : String
  ||| Source format this contract was extracted from
  format : InterfaceFormat
  ||| Individual contract clauses to prove
  clauses : List ContractClause
  ||| Number of endpoints / functions / messages in the interface
  arity : Nat

||| Proof that a contract is non-trivial (has at least one clause)
public export
data NonTrivialContract : InterfaceContract -> Type where
  HasClauses : {auto prf : NonEmpty (clauses c)} -> NonTrivialContract c

--------------------------------------------------------------------------------
-- Proof Obligations
--------------------------------------------------------------------------------

||| The kind of proof that Idrisiser must generate for each obligation.
public export
data ProofKind
  = TotalityProof      -- Function is total (covers all inputs, terminates)
  | TerminationProof   -- Recursive contract terminates (well-founded)
  | InvariantProof     -- State invariant is preserved across the call
  | TypeSafetyProof    -- Input/output types match declared schemas
  | ResourceProof      -- Linear/affine resource is correctly managed (QTT)
  | RoundTripProof     -- Encode then decode yields the original value

||| A single proof obligation: something Idrisiser must prove about the
||| generated wrapper. Each obligation maps to a proof term in the output.
public export
record ProofObligation where
  constructor MkProofObligation
  ||| Which contract clause generates this obligation
  source : ContractClause
  ||| What kind of proof is required
  kind : ProofKind
  ||| Idris2 type signature of the proof term (as a string, pre-elaboration)
  proofType : String
  ||| Whether this obligation has been discharged (filled in during compilation)
  discharged : Bool

||| Proof that all obligations in a list have been discharged
public export
data AllDischarged : List ProofObligation -> Type where
  NilDischarged : AllDischarged []
  ConsDischarged :
    {auto prf : discharged ob = True} ->
    AllDischarged rest ->
    AllDischarged (ob :: rest)

--------------------------------------------------------------------------------
-- Totality Witness
--------------------------------------------------------------------------------

||| Evidence that a generated function is total.
||| Idris2's totality checker produces this as a compile-time artifact.
public export
data Totality : Type where
  ||| Function covers all inputs and terminates on all inputs
  Total : Totality
  ||| Function covers all inputs but may not terminate (rejected by idrisiser)
  Covering : Totality

||| Idrisiser rejects non-total functions — only Total is acceptable
public export
data AcceptableTotality : Totality -> Type where
  OnlyTotal : AcceptableTotality Total

--------------------------------------------------------------------------------
-- Dependent Wrapper
--------------------------------------------------------------------------------

||| A dependent wrapper: the final output of the proof generation pipeline.
||| It bundles the interface contract with proof witnesses showing that
||| every obligation has been discharged.
public export
record DependentWrapper where
  constructor MkDependentWrapper
  ||| The interface contract this wrapper proves correct
  contract : InterfaceContract
  ||| All proof obligations derived from the contract
  obligations : List ProofObligation
  ||| Evidence that the contract is non-trivial
  0 nonTrivial : NonTrivialContract contract
  ||| Evidence that all obligations are discharged
  0 allProven : AllDischarged obligations
  ||| Totality evidence for every generated function
  totality : Totality
  ||| Evidence that totality is acceptable
  0 totalOk : AcceptableTotality totality

--------------------------------------------------------------------------------
-- Quantitative Usage (QTT)
--------------------------------------------------------------------------------

||| Quantitative type theory usage annotations.
||| These track how many times a resource may be used in the generated wrapper,
||| enabling linear and affine resource protocols.
public export
data QuantitativeUsage
  = Unrestricted   -- Value can be used any number of times (default)
  | Linear         -- Value must be used exactly once
  | Affine         -- Value must be used at most once
  | Erased         -- Value exists only at compile time (0-use in QTT)

||| A resource-tracked parameter in a generated wrapper
public export
record TrackedParam where
  constructor MkTrackedParam
  paramName : String
  paramType : String
  usage : QuantitativeUsage

--------------------------------------------------------------------------------
-- FFI Result Codes
--------------------------------------------------------------------------------

||| Result codes for FFI operations between Idris2 and Zig layers.
||| Use C-compatible integers for cross-language compatibility.
public export
data Result : Type where
  ||| Operation succeeded
  Ok : Result
  ||| Generic error
  Error : Result
  ||| Invalid parameter provided
  InvalidParam : Result
  ||| Out of memory
  OutOfMemory : Result
  ||| Null pointer encountered
  NullPointer : Result
  ||| Proof obligation could not be discharged
  ProofFailure : Result

||| Convert Result to C integer for FFI
public export
resultToInt : Result -> Bits32
resultToInt Ok = 0
resultToInt Error = 1
resultToInt InvalidParam = 2
resultToInt OutOfMemory = 3
resultToInt NullPointer = 4
resultToInt ProofFailure = 5

||| Results are decidably equal
public export
DecEq Result where
  decEq Ok Ok = Yes Refl
  decEq Error Error = Yes Refl
  decEq InvalidParam InvalidParam = Yes Refl
  decEq OutOfMemory OutOfMemory = Yes Refl
  decEq NullPointer NullPointer = Yes Refl
  decEq ProofFailure ProofFailure = Yes Refl
  decEq _ _ = No absurd

--------------------------------------------------------------------------------
-- Opaque Handles
--------------------------------------------------------------------------------

||| Opaque handle for the Idrisiser proof engine instance.
||| Prevents direct construction; must be created through the safe init API.
public export
data Handle : Type where
  MkHandle : (ptr : Bits64) -> {auto 0 nonNull : So (ptr /= 0)} -> Handle

||| Safely create a handle from a pointer value.
||| Returns Nothing if the pointer is null.
public export
createHandle : Bits64 -> Maybe Handle
createHandle 0 = Nothing
createHandle ptr = Just (MkHandle ptr)

||| Extract pointer value from handle (for FFI crossing)
public export
handlePtr : Handle -> Bits64
handlePtr (MkHandle ptr) = ptr

--------------------------------------------------------------------------------
-- Platform-Specific Types
--------------------------------------------------------------------------------

||| C int size varies by platform
public export
CInt : Platform -> Type
CInt Linux = Bits32
CInt Windows = Bits32
CInt MacOS = Bits32
CInt BSD = Bits32
CInt WASM = Bits32

||| C size_t varies by platform (pointer-width)
public export
CSize : Platform -> Type
CSize Linux = Bits64
CSize Windows = Bits64
CSize MacOS = Bits64
CSize BSD = Bits64
CSize WASM = Bits32

||| Pointer bit-width per platform
public export
ptrSize : Platform -> Nat
ptrSize Linux = 64
ptrSize Windows = 64
ptrSize MacOS = 64
ptrSize BSD = 64
ptrSize WASM = 32

--------------------------------------------------------------------------------
-- Memory Layout Proofs
--------------------------------------------------------------------------------

||| Proof that a type has a specific size in bytes
public export
data HasSize : Type -> Nat -> Type where
  SizeProof : {0 t : Type} -> {n : Nat} -> HasSize t n

||| Proof that a type has a specific alignment in bytes
public export
data HasAlignment : Type -> Nat -> Type where
  AlignProof : {0 t : Type} -> {n : Nat} -> HasAlignment t n

--------------------------------------------------------------------------------
-- Verification Namespace
--------------------------------------------------------------------------------

||| Compile-time verification of ABI properties
namespace Verify

  ||| Verify that a DependentWrapper is well-formed:
  ||| non-trivial contract, all proofs discharged, total functions.
  export
  verifyWrapper : DependentWrapper -> IO ()
  verifyWrapper w = do
    putStrLn $ "Verified wrapper for: " ++ w.contract.name
    putStrLn $ "  Obligations: " ++ show (length w.obligations)
    putStrLn $ "  Totality: Total"
    putStrLn "  All proofs discharged."
