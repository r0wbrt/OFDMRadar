--Copyright Robert C. Taylor

{- |
Module      :  OFDMRadar.SDR.Converter
Description :  Functions used to convert bytes to symbol stream.
Copyright   :  (c) Robert C. Taylor
License     :  Apache 2.0

Maintainer  :  r0wbrt@gmail.com
Stability   :  unstable 
Portability :  portable 

Primitive functions that are used to write functions and programs that take a 
byte stream as input and produce a symbol stream as output.
-}

module OFDMRadar.SDR.Converters (bytesToSymbols) where

import qualified Data.ByteString as B
import qualified Data.Array as Array
import Data.Word
import Data.Bits
import qualified OFDMRadar.Math.Misc as MathMisc
import Data.Complex

-- | Converts a data block into a list of symbols. Symbols are in LIFO order 
--   and have little edian bit order.
bytesToSymbols :: Int -> Array.Array Word8 (Complex Double) -> 
                                        B.ByteString -> [Complex Double]
bytesToSymbols wordSize constellationArray dataBlock = 
    
    if dataBlock == B.empty || not isWordSizePowerOf2AndSizeMost8 then
        [] 
    else 
        bytesToSymbols wordSize constellationArray (B.tail dataBlock)
            ++ reverse 
                (byteToSymbol constellationArray wordSize 0 (B.head dataBlock))
        
    where isWordSizePowerOf2AndSizeMost8 = ((2 ^ MathMisc.discretePowerOf2 wordSize) == wordSize && wordSize <= 8) || error "bytesToSymbols was supplied with invalid word size"
    
          
byteToSymbol :: Array.Array Word8 (Complex Double) -> Int -> 
                                                Int -> Word8 -> [Complex Double]
byteToSymbol _ _ 8 _ = []
byteToSymbol constellationArray wordSize shiftC byte = 
    (constellationArray Array.! index):byteToSymbol constellationArray wordSize (w8wordSize + shiftC) byte

    --Subtract one to get the bit mask. Assumes wordsize 
    --is a power of 2. Eg 2,4,8,16....
    where index = shiftR byte shiftC .&. setBits (wordSize - 1) 0
          setBits (-1) iByte = iByte
          setBits n iByte = setBits (n - 1) (setBit iByte n)  
          w8wordSize = fromIntegral . toInteger $ wordSize 