module Main where

-- Our modules
import Parsing
import Parsing.Token
import Parsing.Cpt
import Parsing.Ast
import Parsing.Args

main :: IO ()
main = do
    -- Parse args
    parsedArgs <- parseArgs

    -- For the time being since we don't know how to pass args with cabal
    -- we use tokenizeFile immediately

    -- Tokenize
    tokenizedCode <- tokenizeFile "./TestFiles/sample1.scm"

    -- Parse in cpt
    let cpt = parseTokenList(tokenizedCode)

    -- Translate cpt to ast
    let ast = parseExprList cpt

    print ast
