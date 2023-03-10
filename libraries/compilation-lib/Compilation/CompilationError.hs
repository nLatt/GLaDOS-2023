{-# LANGUAGE InstanceSigs #-}

module Compilation.CompilationError where

import Control.Exception

data CompilationError =
    NotAFunction String
    | VariableNotDefined String
    | VariableAlreadyDefined String
    | NonAtomicValue
    | FatalError String
    | Unimplemented
    deriving (Eq)

instance Exception CompilationError

instance Show CompilationError where
    show :: CompilationError -> String
    show (NotAFunction name) = "Error: '" ++ name ++ "' cannot be compiled to function."
    show (VariableNotDefined name) = "Error: '" ++ name ++ "' is not a variable"
    show (VariableAlreadyDefined name) = "Error: '" ++ name ++ "' has already been defined."
    show NonAtomicValue = "Error: List contains "
    show (FatalError name)= "Error: Fatal Error in " ++ name
    show Unimplemented = "Error: This feature of the language has not yet been implemented."