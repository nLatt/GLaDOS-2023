module Exec.InteractivePrompt where

import Data.List ()
import System.Exit ( exitSuccess )
import System.IO ( hFlush, stdout )
import Parsing.Token ( tokenize )
import Parsing.Cpt ( parseTokenList )
import Parsing.Ast ( parseExprList )

-- Function that counts the character received as argument
-- Returns the number of times this character appears in a string
countChar :: Char -> String -> Int
countChar char = length . filter (== char)

-- Function that checks the occurance between '(' and ')'.
-- Returns a boolean
occurenceBrackets :: Int -> Int -> Bool
occurenceBrackets num_open num_close = num_open == num_close && num_open /= 0

-- Recursive function that receives input
-- Reads input, triggers program exit, terminates after good format, recursive if bad
getInput :: [String] -> Int -> IO String
getInput inputs openBrackets = do
  if openBrackets == 0
    then putStr "> "
    else putStr "  "
  hFlush stdout
  input <- getLine
  if input == "\ESC"
    then exitSuccess
    else do
      let num_open = countChar '(' input
      if (openBrackets + num_open) == 0
        then do
          print "Open with a bracket."
          getInput [] 0
        else do
          let num_close = countChar ')' input
          if (openBrackets + num_open) == num_close
            then return $ concat (inputs <> [input ++ "\n"])
            else do
              getInput (inputs <> [input ++ "\n"]) ((openBrackets + num_open) - num_close)

interactiveMode :: IO ()
interactiveMode = do
    putStrLn "*** BONUS GLADOS ***"

    tokens <- tokenize <$> getInput [] 0

    -- Parse CPT
    let cpt = parseTokenList tokens

    -- Parse AST
    let ast = parseExprList cpt

    -- Run
    putStrLn "NOT IMPLEMENTED"
    return ()

-- Fonction main
--  Affiche entrée "input" au bon format
-- get the return of the "checkBrackets" function
-- which gives the correct test format with true occurance '(' == ')'