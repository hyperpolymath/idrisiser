-- SPDX-License-Identifier: PMPL-1.0-or-later
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
--
||| Foreign Function Interface Declarations for Idrisiser
|||
||| This module declares the C-compatible FFI between the Idris2 proof engine
||| and the Zig implementation layer.  All functions listed here are implemented
||| in src/interface/ffi/src/main.zig.
|||
||| The FFI surface covers three concerns:
|||   1. Proof engine lifecycle (init, free, status)
|||   2. Interface parsing and proof generation (parse, prove, compile)
|||   3. Proof checking and result retrieval (check, query)
|||
||| @see Idrisiser.ABI.Types for type definitions
||| @see Idrisiser.ABI.Layout for memory layout proofs

module Idrisiser.ABI.Foreign

import Idrisiser.ABI.Types
import Idrisiser.ABI.Layout

%default total

--------------------------------------------------------------------------------
-- Proof Engine Lifecycle
--------------------------------------------------------------------------------

||| Initialise the Idrisiser proof engine.
||| Allocates internal state for interface parsing and proof generation.
||| Returns a handle to the engine instance, or Nothing on failure.
export
%foreign "C:idrisiser_init, libidrisiser"
prim__init : PrimIO Bits64

||| Safe wrapper for engine initialisation
export
init : IO (Maybe Handle)
init = do
  ptr <- primIO prim__init
  pure (createHandle ptr)

||| Shut down the proof engine and release all resources.
export
%foreign "C:idrisiser_free, libidrisiser"
prim__free : Bits64 -> PrimIO ()

||| Safe wrapper for engine cleanup
export
free : Handle -> IO ()
free h = primIO (prim__free (handlePtr h))

||| Check whether the engine handle is live and initialised
export
%foreign "C:idrisiser_is_initialized, libidrisiser"
prim__isInitialized : Bits64 -> PrimIO Bits32

||| Safe initialisation check
export
isInitialized : Handle -> IO Bool
isInitialized h = do
  result <- primIO (prim__isInitialized (handlePtr h))
  pure (result /= 0)

--------------------------------------------------------------------------------
-- Interface Parsing
--------------------------------------------------------------------------------

||| Parse an interface definition file and load it into the engine.
||| The format parameter selects the parser (OpenAPI, C header, protobuf, etc.).
||| Returns 0 on success, non-zero on parse error.
export
%foreign "C:idrisiser_parse_interface, libidrisiser"
prim__parseInterface : Bits64 -> Bits64 -> Bits32 -> PrimIO Bits32

||| Safe wrapper for interface parsing.
||| Takes the engine handle, a pointer to the file path string, and the
||| interface format code (0 = OpenAPI, 1 = CHeader, 2 = ProtoBuf, 3 = TypeSig).
export
parseInterface : Handle -> (pathPtr : Bits64) -> (format : Bits32) -> IO (Either Result ())
parseInterface h pathPtr fmt = do
  result <- primIO (prim__parseInterface (handlePtr h) pathPtr fmt)
  pure $ case result of
    0 => Right ()
    n => Left (resultFromCode n)
  where
    resultFromCode : Bits32 -> Result
    resultFromCode 1 = Error
    resultFromCode 2 = InvalidParam
    resultFromCode 3 = OutOfMemory
    resultFromCode 4 = NullPointer
    resultFromCode 5 = ProofFailure
    resultFromCode _ = Error

--------------------------------------------------------------------------------
-- Proof Generation
--------------------------------------------------------------------------------

||| Generate proof obligations from the currently loaded interface.
||| Must be called after a successful parseInterface call.
||| Returns the number of proof obligations generated, or 0 on failure.
export
%foreign "C:idrisiser_generate_proofs, libidrisiser"
prim__generateProofs : Bits64 -> PrimIO Bits32

||| Safe wrapper for proof generation
export
generateProofs : Handle -> IO (Either Result Nat)
generateProofs h = do
  count <- primIO (prim__generateProofs (handlePtr h))
  if count == 0
    then pure (Left Error)
    else pure (Right (cast count))

||| Compile all generated proof obligations through the Idris2 type checker.
||| This is the core operation: it invokes totality checking, elaborator
||| reflection, and QTT analysis on the generated Idris2 code.
||| Returns 0 if all proofs pass, non-zero on proof failure.
export
%foreign "C:idrisiser_compile_proofs, libidrisiser"
prim__compileProofs : Bits64 -> PrimIO Bits32

||| Safe wrapper for proof compilation
export
compileProofs : Handle -> IO (Either Result ())
compileProofs h = do
  result <- primIO (prim__compileProofs (handlePtr h))
  pure $ case result of
    0 => Right ()
    _ => Left ProofFailure

--------------------------------------------------------------------------------
-- Proof Checking and Results
--------------------------------------------------------------------------------

||| Query the number of discharged (successfully proven) obligations.
export
%foreign "C:idrisiser_discharged_count, libidrisiser"
prim__dischargedCount : Bits64 -> PrimIO Bits32

||| Get the count of discharged proof obligations
export
dischargedCount : Handle -> IO Nat
dischargedCount h = do
  count <- primIO (prim__dischargedCount (handlePtr h))
  pure (cast count)

||| Query the number of remaining (unproven) obligations.
export
%foreign "C:idrisiser_remaining_count, libidrisiser"
prim__remainingCount : Bits64 -> PrimIO Bits32

||| Get the count of remaining proof obligations
export
remainingCount : Handle -> IO Nat
remainingCount h = do
  count <- primIO (prim__remainingCount (handlePtr h))
  pure (cast count)

--------------------------------------------------------------------------------
-- Native Wrapper Output
--------------------------------------------------------------------------------

||| Emit the native wrapper (shared library) to the specified output path.
||| Must be called after all proofs are compiled and discharged.
export
%foreign "C:idrisiser_emit_wrapper, libidrisiser"
prim__emitWrapper : Bits64 -> Bits64 -> PrimIO Bits32

||| Safe wrapper for native output emission
export
emitWrapper : Handle -> (outputPathPtr : Bits64) -> IO (Either Result ())
emitWrapper h outPtr = do
  result <- primIO (prim__emitWrapper (handlePtr h) outPtr)
  pure $ case result of
    0 => Right ()
    _ => Left Error

--------------------------------------------------------------------------------
-- String Operations
--------------------------------------------------------------------------------

||| Convert C string pointer to Idris String
export
%foreign "support:idris2_getString, libidris2_support"
prim__getString : Bits64 -> String

||| Free a C string allocated by the engine
export
%foreign "C:idrisiser_free_string, libidrisiser"
prim__freeString : Bits64 -> PrimIO ()

||| Get a diagnostic or result string from the engine
export
%foreign "C:idrisiser_get_string, libidrisiser"
prim__getResult : Bits64 -> PrimIO Bits64

||| Safely retrieve a string result from the engine
export
getString : Handle -> IO (Maybe String)
getString h = do
  ptr <- primIO (prim__getResult (handlePtr h))
  if ptr == 0
    then pure Nothing
    else do
      let str = prim__getString ptr
      primIO (prim__freeString ptr)
      pure (Just str)

--------------------------------------------------------------------------------
-- Error Handling
--------------------------------------------------------------------------------

||| Get the last error message from the engine
export
%foreign "C:idrisiser_last_error, libidrisiser"
prim__lastError : PrimIO Bits64

||| Retrieve last error as string
export
lastError : IO (Maybe String)
lastError = do
  ptr <- primIO prim__lastError
  if ptr == 0
    then pure Nothing
    else pure (Just (prim__getString ptr))

||| Human-readable description for each result code
export
errorDescription : Result -> String
errorDescription Ok = "Success"
errorDescription Error = "Generic error"
errorDescription InvalidParam = "Invalid parameter"
errorDescription OutOfMemory = "Out of memory"
errorDescription NullPointer = "Null pointer"
errorDescription ProofFailure = "Proof obligation could not be discharged"

--------------------------------------------------------------------------------
-- Version Information
--------------------------------------------------------------------------------

||| Get engine version string
export
%foreign "C:idrisiser_version, libidrisiser"
prim__version : PrimIO Bits64

||| Get version as string
export
version : IO String
version = do
  ptr <- primIO prim__version
  pure (prim__getString ptr)

||| Get build information (compiler, platform, flags)
export
%foreign "C:idrisiser_build_info, libidrisiser"
prim__buildInfo : PrimIO Bits64

||| Get build information
export
buildInfo : IO String
buildInfo = do
  ptr <- primIO prim__buildInfo
  pure (prim__getString ptr)
