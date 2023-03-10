module Parsing.Token where

import Utils (isPositiveInt, isNegativeInt, isPositiveFloat, isNegativeFloat)
import Parsing.TokenType
import Compilation.CompilationError ( CompilationError(FatalError) )
import Control.Exception (throw)

-- ─── Tokenization ────────────────────────────────────────────────────────────────────────────────

-- Parse token from string
parseToken :: String -> Token
parseToken "(" = OpenScope
parseToken ")" = CloseScope
parseToken input
        | isPositiveInt input = Num (read input :: Integer)
        | isNegativeInt input = Num $ negate (read (tail input) :: Integer)
        | isPositiveFloat input =  Flt (read input :: Float)
        | isNegativeFloat input = Flt $ negate (read (tail input) :: Float)
parseToken input = Keyword input

-- Function that tokenizes string
--
-- Tokens are : ' ', '\n', '(', ')'
-- Args are : Input -> Temp Str -> Output List
tokenize' :: String -> String -> [Token]
tokenize' [] "" = []
tokenize' [] str = [parseToken str]
tokenize' (' ':xs) "" = tokenize' xs ""
tokenize' (' ':xs) str = parseToken str : tokenize' xs ""
tokenize' (',':xs) str = parseToken str : tokenize' xs ""
tokenize' ('\n':xs) "" = tokenize' xs ""
tokenize' ('\n':xs) str = parseToken str : tokenize' xs ""
tokenize' ('(':xs) "" = OpenScope : tokenize' xs ""
tokenize' ('(':xs) str = parseToken str : tokenize' ('(':xs) ""
tokenize' (')':xs) "" = CloseScope : tokenize' xs ""
tokenize' (')':xs) str = parseToken str : tokenize' (')':xs) ""
tokenize' ('[':xs) "" = OpenScope : tokenize' xs ""
tokenize' ('[':xs) str = parseToken str : tokenize' ('(':xs) ""
tokenize' (']':xs) "" = CloseScope : tokenize' xs ""
tokenize' (']':xs) str = parseToken str : tokenize' (')':xs) ""
tokenize' ('"':xs) "" = parseString ('"':xs) : tokenize' (stringFastForward xs) ""
tokenize' ('"':xs) str = parseToken str : parseString ('"':xs) : tokenize' (stringFastForward xs) ""
tokenize' (x:xs) str = tokenize' xs (str <> [x])

-- Utility entry point function
tokenize :: String -> [Token]
tokenize str = tokenize' str ""

-- Function to tokenize a given file
--
-- Args : path
tokenizeFile :: String -> IO [Token]
tokenizeFile path = do
        -- Read file and Tokenize
        fileStr <- readFile path

        -- Return tokenization result
        return (tokenize fileStr)

-- ─── String Parsing ──────────────────────────────────────────────────────────────────────────────

parseString' :: String -> String
parseString' ('\\' : x : xs ) = x : parseString' xs
parseString' ('"' : _) = ""
parseString' (x : xs) = x : parseString' xs
parseString' _ = throw $ FatalError "parseString'"

parseString :: String -> Token
parseString ('"' : str) = Literal $ parseString' str
parseString _ = throw $ FatalError "parseString"

stringFastForward :: String -> String
stringFastForward ('\\' : _ : xs ) = stringFastForward xs
stringFastForward ('"' : xs) = xs
stringFastForward (_ : xs) = stringFastForward xs
stringFastForward _ = throw $ FatalError "stringFastForward"
