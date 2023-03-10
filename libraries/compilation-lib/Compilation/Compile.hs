module Compilation.Compile where

import qualified Parsing.Ast as Ast
import Compilation.Utils ( isAtomic, isSymbol )
import Compilation.RetVal ( RetVal(..), concatRetVal )
import Compilation.Registry
import Compilation.CompilationError
import FunctionBlock ( FunctionBlock(..) )
import Instruction ( Instruction(Move, Call, Push, Init, Pop, Conditional) )
import Control.Exception ( throw )

-- ─── Compile Expression ──────────────────────────────────────────────────────────────────────────

isLambda :: Ast.Expr -> Bool
isLambda (Ast.Call "define" (_ : Ast.Call "lambda" _ : _)) = True
isLambda _ = False

-- Compiles and Ast Expression
--
-- This is essentially the main function for compilation,
--    asides from the compileProgram func
-- Args : Expression -> Registry -> Defined Functions
-- Return : (Instructions (if not function def), Updated function definitions)
compileExpr :: Ast.Expr -> Registry -> RetVal
compileExpr expr reg | isLambda expr = compileFunction expr reg

compileExpr (Ast.Call "if" body) reg = compileConditional (Ast.Call "if" body) reg
compileExpr (Ast.Call "define" ((Ast.Symbole s) : val)) reg = compileVariable call reg
    where call = Ast.Call "define" (Ast.Symbole s : val)

compileExpr (Ast.Call funcName args) reg = compileCall (Ast.Call funcName args) reg
compileExpr (Ast.ExprList (Ast.Symbole sym : xs)) reg | sym `elem` fst reg = compileCall (Ast.Call sym xs) reg
compileExpr _ _ = throw $ FatalError "compileExpr"

-- ─── Compilation Main Functions ──────────────────────────────────────────────────────────────────

-- Compiles a list of expressions
--
-- This will compile all instructions inside a retval as well as saving additional function declarations
compileExprList' :: Ast.Expr -> Registry -> RetVal
compileExprList' (Ast.ExprList (x:xs)) reg = concatRetVal compiledExpr compiledLeftover
    where
        compiledExpr = compileExpr x reg
        (RetVal _ _ updatedReg) = compiledExpr
        compiledLeftover = compileExprList' (Ast.ExprList xs) updatedReg
compileExprList' (Ast.ExprList []) reg = RetVal [] [] reg
compileExprList' _ _ = throw $ FatalError "compileExprList'"

-- Entry point function for compileExprList'
compileExprList :: Ast.Expr -> Registry -> RetVal
compileExprList (Ast.ExprList ls) reg = compileExprList' list reg
    where list = Ast.ExprList ls
compileExprList _ _ = throw $ FatalError "compileExprList"

-- Compiles program into list of FunctionBlock INCLUDING main func
-- Arg : ExprList to be compiled (corresponds to base depth level of input code)
compileProgram :: Ast.Expr -> [FunctionBlock]
compileProgram list = output
    where
        (RetVal instrs funcs _) = compileExprList list emptyRegistry
        mainFunc = Function "main" instrs
        output = mainFunc : funcs

-- ─── Special Interactive Functions ───────────────────────────────────────────────────────────────
--
-- The following are special function adaptations to enable the implementation

-- Function used to pass pre existing reg and return
compileProgramAddition :: Ast.Expr -> Registry -> ([FunctionBlock], Registry)
compileProgramAddition list reg = (output, newReg)
    where
        (RetVal instrs funcs newReg) = compileExprList' list reg
        mainFunc = Function "main" instrs
        output = mainFunc : funcs

-- ─── Function Compilation ────────────────────────────────────────────────────────────────────────

isCall :: Ast.Expr -> Bool
isCall (Ast.Call _ _) = True
isCall _ = False
-- Compiles an ExprList into instructions required for the function call
-- Args are compiled from last to first
--
-- Args : Ast.ExprList -> Reg
compileCallArgs :: Ast.Expr -> Registry -> RetVal
compileCallArgs (Ast.ExprList []) reg = RetVal [] [] reg
compileCallArgs (Ast.ExprList (Ast.Symbole name : x)) reg | name `elem` fst reg = compileCall (Ast.Call name x) reg
compileCallArgs (Ast.ExprList (x:xs)) reg | isAtomic x || isSymbol x = RetVal (Push (show x) : instr) [] reg
    where (RetVal instr _ _) = compileCallArgs (Ast.ExprList xs) reg
compileCallArgs (Ast.ExprList (x:xs)) reg = concatRetVal ret (RetVal instr [] reg)
    where
        (RetVal instr _ _) = compileCallArgs (Ast.ExprList xs) reg
        ret = compileExpr x reg 
compileCallArgs _ _ = throw $ FatalError "compileCallArgs"

flipL :: [a] -> [a]
flipL = foldl (flip (:)) []

--
-- Compiles function call as well as args (calls compileCallArgs)
--
compileCall :: Ast.Expr -> Registry -> RetVal
compileCall (Ast.Call funcName args) reg | isAtomic (Ast.ExprList args) = RetVal instruction [] reg
    where instruction = [Push $ show arg | arg <- flipL args] ++ [Call funcName, Push "#RET"] 
compileCall (Ast.Call funcName args) reg = RetVal (instructions ++ [Call funcName, Push "#RET"]) [] reg
    where (RetVal instructions _ _) = compileCallArgs (Ast.ExprList $ flipL args) reg
compileCall (Ast.ExprList (Ast.Symbole name : args)) reg | name `elem` fst reg = compileCall (Ast.Call name args) reg
compileCall _ _ = throw $ FatalError "compileCall"

-- This function attempts to convert an Ast.ExprList to a Ast.Call
-- If the function does not exist, it returns Nothing
-- Args : Input ExprList + Registry
-- Output : Ast.Call
convertToCall :: Ast.Expr -> Registry -> Maybe Ast.Expr
convertToCall (Ast.ExprList (Ast.Symbole name : ls)) reg = if isFunction name reg
    then Just $ Ast.Call name ls
    else Nothing
convertToCall _ _ = Nothing

-- ─── Variable Compilation ────────────────────────────────────────────────────────────────────────

-- Compiles instructions required for variable compilation
--
-- Note : This does not check the registry if the variable is already defined
-- Args : Ast.Call (Expected to haveproper define form for a variable definition) -> reg -> functions
compileVariable :: Ast.Expr -> Registry -> RetVal
compileVariable (Ast.Call "define" [Ast.Symbole s1, Ast.Symbole s2]) reg = if isVariable s2 reg
    then RetVal instructions [] newReg
    else throw $ VariableNotDefined s2
        where
            newReg = addVar s1 reg
            instructions = [Init s1, Move s1 s2]
compileVariable (Ast.Call "define" [Ast.Symbole s, atom]) reg = if isAtomic atom
    then RetVal instructions [] newReg
    else throw NonAtomicValue
        where
            newReg = addVar s reg
            instructions = [Init s, Move s $ show atom]
compileVariable _ _ = throw $ FatalError "compileVariable"


takeNames :: [Ast.Expr] -> [String]
takeNames [] = []
takeNames (Ast.Symbole x : xs) =  x : takeNames xs
takeNames _ = throw $ FatalError "takeNames"


compileFunction :: Ast.Expr -> Registry -> RetVal
compileFunction (Ast.Call "define" [Ast.Symbole name, Ast.Call "lambda" [Ast.ExprList args, astBody]]) reg = RetVal [] [Function name (popedArgs ++  body)] newReg
    where
        popedArgs = map Pop (takeNames args)
        (RetVal body _ newReg) = compileExpr astBody (addVars (takeNames args) (addFunction name reg))
compileFunction _ _ = throw $ FatalError "compileFunction"

compileBranch :: Ast.Expr -> Registry -> RetVal
compileBranch a | isAtomic a = RetVal [Push $ show a] []
compileBranch a = compileExpr a

compileConditional :: Ast.Expr -> Registry -> RetVal
compileConditional (Ast.Call _ [astCond, astLBranch, astRBranch]) reg = RetVal [Conditional cond lBranch rBranch] [] reg
    where
        (RetVal cond _ _) = compileBranch astCond reg
        (RetVal lBranch _ _) = compileBranch astLBranch reg
        (RetVal rBranch _ _) = compileBranch astRBranch reg
compileConditional _ _ = throw $ FatalError "compileFunction"
