--Copyright Robert C. Taylor - All Rights Reserved

{- |
Module      :  OFDMRadar.IO.ComplexSerialization
Description :  Functionality to serialize and deserialize streams of complex numbers.
Copyright   :  (c) Robert C. Taylor
License     :  Apache 2.0

Maintainer  :  r0wbrt@gmail.com
Stability   :  unstable 
Portability :  portable 

Functionality to serialize and deserialize streams of complex numbers. Supports
serializing and deserializing both complex float and complex SC11. 
-}

module OFDMRadar.IO.ComplexSerialization (
                                            BinaryParserExceptions 
                                                ( DidNotExpectIncompleteData,
                                                    FailedWhileParsing,
                                                        UnhandledExtraInput),
            deserializeBlock, serializeBlock, blockListDeserializer,
            blockListSerializer, complexFloatSerializer,
            complexFloatDeserializer, complexSC11Deserializer,
            complexSC11Serializer) where

import qualified Data.Binary.Get as BG
import qualified Data.Binary.Put as BP
import qualified Data.ByteString as B
import qualified Data.ByteString.Lazy as BL
import Data.Complex
import GHC.Float
import Control.Exception
import Data.Typeable


data BinaryParserExceptions = DidNotExpectIncompleteData String 
                            | FailedWhileParsing String 
                            | UnhandledExtraInput String  
    deriving (Show, Typeable)
instance Exception BinaryParserExceptions

deserializationStreamProcessor :: BG.Get a -> [a] -> BG.Get [a]
deserializationStreamProcessor decoder acc = do
    
    noMoreData <- BG.isEmpty

    if noMoreData then
         return (reverse acc)
         
    else 
        do
            --Grab output
            sample <- decoder
            deserializationStreamProcessor decoder (sample:acc)

deserializeBlock :: BG.Get a -> B.ByteString -> ([a], B.ByteString)
deserializeBlock decoder block = 
        
    --Run the decoder and handle it three possible output.
    case BG.pushEndOfInput $ BG.pushChunk bgdecoder block of
         
        --Something went wrong
        BG.Fail _ _ msg -> throw $ FailedWhileParsing msg
        
        --Not all the data was passed in.
        BG.Partial _ -> throw $ DidNotExpectIncompleteData "Expected parsing to be complete, however decoder is still expecting more input"
        
        --All data was passed in and decoded.
        BG.Done extraData _ sampleSequence -> (sampleSequence, extraData)                                                
        
    where bgdecoder = BG.runGetIncremental (deserializationStreamProcessor decoder [])
 
 
-- | Parses a list of types into a byte stream
serializationStreamProcessor :: (a -> BP.Put) -> [a] -> BP.Put
serializationStreamProcessor _ [] = return ()
serializationStreamProcessor parser (x:xs) = do
    parser x 
    serializationStreamProcessor parser xs
    
serializeBlock :: (a -> BP.Put) -> [a] -> B.ByteString
serializeBlock encoder block = BL.toStrict $ BP.runPut puter
                                              
    where puter = serializationStreamProcessor encoder block

    
blockListDeserializer :: BG.Get a -> Int -> BG.Get [a]
blockListDeserializer _ 0 = return []
blockListDeserializer decoder size = do
    signalHead <- decoder
    signalTail <- blockListDeserializer decoder (size - 1)
    return (signalHead:signalTail)

    
blockListSerializer :: (a -> BP.Put) -> [a] -> BP.Put
blockListSerializer _ [] = return ()
blockListSerializer encoder input = do
    
    encoder (head input)
    
    blockListSerializer encoder (tail input)


complexFloatSerializer :: Complex Double -> BP.Put
complexFloatSerializer (real :+ imaginary) = do
    
    BP.putFloatle (double2Float real)
    BP.putFloatle (double2Float imaginary)

    
complexFloatDeserializer :: BG.Get (Complex Double)
complexFloatDeserializer = do
    
    real <- BG.getFloatle 
    imaginary <- BG.getFloatle
    
    return (float2Double real :+ float2Double imaginary)


complexSC11Serializer :: Complex Double -> BP.Put
complexSC11Serializer (real :+ imaginary) = do
    
    BP.putInt16le $ convertNumber real
    BP.putInt16le $ convertNumber imaginary
    
    --Helper function to scale and then convert the number
    where convertNumber number = floor $ signum number * abs (minimum [2047.0 * number, 2047.0])


complexSC11Deserializer :: BG.Get (Complex Double)
complexSC11Deserializer = do
    
    --First parse the data from the stream
    real <- BG.getWord16le
    imaginary <- BG.getWord16le
    
    --Next scale the data accordingly
    let realD = fromIntegral real / 2048.0
    let imagD = fromIntegral imaginary / 2048.0
    
    --Return the result.
    return (realD :+ imagD)