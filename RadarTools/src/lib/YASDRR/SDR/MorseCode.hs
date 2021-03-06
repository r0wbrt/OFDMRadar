{-

Copyright 2017 Robert Christian Taylor

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

-}


{- |
Module      :  YASDRR.SDR.MorseCode
Description :  Functions used to generate Morse Code Signals
Copyright   :  (c) Robert C. Taylor
License     :  Apache 2.0

Maintainer  :  r0wbrt@gmail.com
Stability   :  unstable
Portability :  portable

Functionality used to generate morse code signals for identification purposes.
-}


module YASDRR.SDR.MorseCode
        ( convertStringToMorseCode,
          wpmToDotLength,
          MorseSymbol (MorseDot, MorseDash, MorseSpace)
         ) where


import qualified Data.Char    as DChar
import qualified Data.HashMap as Map
import           Data.Maybe


data MorseSymbol = MorseDot | MorseDash | MorseSpace deriving (Show,Eq)


-- | table of morse characters.
letterTable :: [(Char, [MorseSymbol])]
letterTable =
    [ ('A',[MorseDot, MorseDash])
    , ('B',[MorseDash, MorseDot, MorseDot, MorseDot])
    , ('C',[MorseDash, MorseDot, MorseDash, MorseDot])
    , ('D',[MorseDash, MorseDot, MorseDot])
    , ('E',[MorseDot])
    , ('F',[MorseDot, MorseDot, MorseDash, MorseDot])
    , ('G',[MorseDash, MorseDash, MorseDot])
    , ('H',[MorseDot, MorseDot, MorseDot, MorseDot])
    , ('I',[MorseDot, MorseDot])
    , ('J',[MorseDot, MorseDash, MorseDash, MorseDash])
    , ('K',[MorseDash, MorseDot, MorseDash])
    , ('L',[MorseDot, MorseDash, MorseDot, MorseDot])
    , ('M',[MorseDash, MorseDash])
    , ('N',[MorseDash, MorseDot])
    , ('O',[MorseDash, MorseDash, MorseDash])
    , ('P',[MorseDot, MorseDash, MorseDash, MorseDot])
    , ('Q',[MorseDash, MorseDash, MorseDot, MorseDash])
    , ('R',[MorseDot, MorseDash, MorseDot])
    , ('S',[MorseDot, MorseDot, MorseDot])
    , ('T',[MorseDash])
    , ('U',[MorseDot, MorseDot, MorseDash])
    , ('V',[MorseDot, MorseDot, MorseDot, MorseDash])
    , ('W',[MorseDot, MorseDash, MorseDash])
    , ('X',[MorseDash, MorseDot, MorseDot, MorseDash])
    , ('Y',[MorseDash, MorseDot, MorseDash, MorseDash])
    , ('Z',[MorseDash, MorseDash, MorseDot, MorseDot])
    , ('0',[MorseDash, MorseDash, MorseDash, MorseDash, MorseDash])
    , ('1',[MorseDot, MorseDash, MorseDash, MorseDash, MorseDash])
    , ('2',[MorseDot, MorseDot, MorseDash, MorseDash, MorseDash])
    , ('3',[MorseDot, MorseDot, MorseDot, MorseDash, MorseDash])
    , ('4',[MorseDot, MorseDot, MorseDot, MorseDot, MorseDash])
    , ('5',[MorseDot, MorseDot, MorseDot, MorseDot, MorseDot])
    , ('6',[MorseDash, MorseDot, MorseDot, MorseDot, MorseDot])
    , ('7',[MorseDash, MorseDash, MorseDot, MorseDot, MorseDot])
    , ('8',[MorseDash, MorseDash, MorseDash, MorseDot, MorseDot])
    , ('9',[MorseDash, MorseDash, MorseDash, MorseDash, MorseDot])
    , ('.',[MorseDot, MorseDash, MorseDot, MorseDash, MorseDot, MorseDash])
    , (',',[MorseDash, MorseDash, MorseDot, MorseDot, MorseDash, MorseDash])
    , ('?',[MorseDot, MorseDot, MorseDash, MorseDash, MorseDot, MorseDot])
    , ('=',[MorseDash, MorseDot, MorseDot, MorseDot, MorseDash])
    ]


-- | Table of special morse symbols, like the space between words.
symbolTable :: [(Char, [MorseSymbol])]
symbolTable =
    [ (' ', [MorseSpace, MorseSpace, MorseSpace, MorseSpace]) ]


-- | The actual hash map that maps chars to morse characters.
morseMap :: Map.Map Char [MorseSymbol]
morseMap = Map.union letterMap symbolMap

    where letterMap = foldl insertIntoMap Map.empty (adjustLetterTable letterTable)

          symbolMap = foldl insertIntoMap Map.empty symbolTable

          insertIntoMap hMap (k, value) = Map.insert (DChar.toUpper k) value hMap

          adjustLetterTable = map (\(k, value) -> (k, init $ insertLetterSpaces value))

          insertLetterSpaces = concatMap (\symbol -> [symbol, MorseSpace])


-- | Converts a list of chars (a string) into their equivalent morse code
-- representation.
convertStringToMorseCode :: String -> [MorseSymbol]
convertStringToMorseCode input =
    take (length (morseString sanitizedString) - 3) $ morseString sanitizedString

    where morseString = concatMap letterToMorse

          sanitizedString = unwords $ words input

          letterToMorse ' ' = fromJust (Map.lookup ' ' morseMap)

          letterToMorse c =
              fromJust (Map.lookup (DChar.toUpper c) morseMap)
                ++ [MorseSpace, MorseSpace, MorseSpace]


-- | Converts wpm to dot length as a fraction of a second.
wpmToDotLength :: Int -> Float
wpmToDotLength wpm = 1.2 / fromIntegral wpm


