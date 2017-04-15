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
Module      :  YASDRR.SDR.OFDMModulation
Description :  Functions used to create OFDM signals
Copyright   :  (c) Robert C. Taylor
License     :  Apache 2.0

Maintainer  :  r0wbrt@gmail.com
Stability   :  unstable
Portability :  portable

Functionality to encode bytestreams into symbols as well as generate OFDM
signals.
-}

module YASDRR.SDR.OFDMModulation
    ( extendOFDMSymbol
    , processOfdmRadarReturnV
    , encodeOFDMSymbol
    ) where

import qualified Data.Array              as Array
import qualified Data.ByteString         as B
import           Data.Word
import qualified YASDRR.DSP.Correlation  as Correlation
import qualified YASDRR.DSP.FFT          as DSPFft
import qualified YASDRR.Math.Misc        as MathMisc
import qualified YASDRR.SDR.Converters   as SDRConverters
import qualified YASDRR.SDR.DopplerRadar as DopplerRadar

import           Data.Complex
import qualified Data.Vector             as VB
import qualified Data.Vector.Unboxed     as VUB

-- | extends an OFDM symbol by applying silence and cyclic prefix to it.
extendOFDMSymbol :: Int -> Int -> [Complex Double] -> [Complex Double]
extendOFDMSymbol _ _ [] = []
extendOFDMSymbol cyclicLength lengthOfSilence symbol =
    prefix ++ symbol ++ silence

    where prefix = reverse $ take cyclicLength $ cycle $ reverse symbol

          silence = replicate lengthOfSilence (0 :+ 0)


-- | Encodes a data block into an OFDM Symbol
encodeOFDMSymbol :: Int -> Array.Array Word8 (Complex Double) ->
                                        Int -> B.ByteString -> [Complex Double]
encodeOFDMSymbol 0 _ _ _ = []
encodeOFDMSymbol _ _ 0 _ = []

encodeOFDMSymbol symbolSize symbolMapping carrierCount dataBlock =

    --Convert the data only if it is valid.
    if carrierIsPowerOf2 && inputDataBlockValid then

        ifft symbols

                  else error "Number of symbols provided did not match the number of desired carriers or number of carriers was not a power of 2 for encodeOFDMSymbol."

    --Set up inverse FFT
    where ifft = DSPFft.createFft carrierCount 1

          --Check to make sure the number of provided
          --symbols match the carrierCount
          numberOfSymbols = div (B.length dataBlock * 8) symbolSize

          --Carrier count should be a power of 2.
          --Number of carriers should at least be greater then 8
          carrierIsPowerOf2 =
              (2 ^ MathMisc.discretePowerOf2 carrierCount) == carrierCount
              && carrierCount*symbolSize >=8
              || error "Number of carriers is not a power of 2 or symbols * carriers is less then 8"

          --Conditions to check.
          inputDataBlockValid =
              (numberOfSymbols == carrierCount)
              || error "Number of symbols does not match the number of carriers"

          --To Symbols creates a stream of symbols where the first symbol is at the end of the list.
          --Reverse so the first symbol of the first byte is at the head of the list
          symbols = reverse $ SDRConverters.bytesToSymbols symbolSize symbolMapping dataBlock

-- | Demodulates an OFDM Radar return.
processOfdmRadarReturnV :: VUB.Vector (Complex Double) -> Double ->
                                    VB.Vector (VUB.Vector (Complex Double)) ->
                                        VB.Vector (VUB.Vector (Complex Double))
processOfdmRadarReturnV impulse shift pulses =
    DopplerRadar.processDopplerReturnV $
        VB.map (Correlation.correlateV impulse) $
            DSPFft.cyclicMutateMatrixV shift (VUB.length $ pulses VB.! 0) pulses
