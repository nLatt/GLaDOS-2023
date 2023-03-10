module Exec where
import Exec.InferType (Stack (Stack), StackFrame (StackFrame), makeStackFrame, Type)
import FunctionBlock (FunctionBlock (Function))
import Instruction (Instruction (Push, Call, Pop, Conditional, Init, Move))
import Data.Maybe (fromJust, fromMaybe)
import Exec.Instructions (pushVal, popVal, initVar, moveVar)
import Exec.Infer (infer)
import Exec.Builtins (execBuiltin)
import Utils (isValidBuiltin)
import Exec.Utils (lookupRet)
import qualified Exec.InferType as Type
import qualified Data.Map
import Control.Exception (throw)
import Exec.RuntimeException (RuntimeException(FatalError))

currSF :: Stack -> StackFrame
currSF (Stack (s:_) _ _) = s
currSF _ = throw $ FatalError ""

getCurrentFunc :: [FunctionBlock] -> String -> Maybe FunctionBlock
getCurrentFunc [] _ = Nothing
getCurrentFunc (f:_) a | funcName == a = Just f
    where Function funcName _ = f
getCurrentFunc (_:fs) a = getCurrentFunc fs a

resolveVar :: String -> Stack -> Type
resolveVar "#RET" (Stack _ _ reg) = fromJust $ lookupRet reg
resolveVar str stack = fromMaybe (infer str) $ Data.Map.lookup (Type.Symbol str) v
    where StackFrame v _ _ = currSF stack

executeCond :: [FunctionBlock] -> [Instruction] -> [Instruction] -> [Instruction] -> Stack -> IO Stack
executeCond c cond lBranch rBranch stack = do
    (Stack sf (res:as) newReg) <- processInstr c cond stack
    let condRes = res == Type.Boolean True
    if condRes
        then processInstr c lBranch (Stack sf as newReg)
        else processInstr c rBranch (Stack sf as newReg)

processInstr :: [FunctionBlock] -> [Instruction] -> Stack -> IO Stack
processInstr _ [] stack = return stack
processInstr c (Push a:is) stack = processInstr c is (pushVal val stack)
    where val = resolveVar a stack
processInstr c (Pop a:is) stack = processInstr c is (popVal (infer a) stack)
processInstr c (Init a:is) stack = processInstr c is (initVar (infer a) stack)
processInstr c (Move a b:is) stack = processInstr c is (moveVar (infer a) (infer b) stack)
processInstr c (Call a:is) stack = executeFunc c a stack >>= processInstr c is
processInstr c (Conditional cond lBranch rBranch : is) stack = executeCond c cond lBranch rBranch stack >>= processInstr c is

executeFunc :: [FunctionBlock] -> String -> Stack -> IO Stack
executeFunc _ name stack | isValidBuiltin name = execBuiltin (infer name) stack
executeFunc code name (Stack stackFr argStack reg) = processInstr code instructions newStack
    where
        Function _ instructions = fromJust $ getCurrentFunc code name
        newStack = Stack (makeStackFrame name 0 : stackFr) argStack reg