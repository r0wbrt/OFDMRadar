--Copyright Robert C. Taylor - All Rights Reserved

{- |
Module      :  OFDMRadar.DSP.FFT
Description :  Functions to calculate the FFT of lists and vectors data.
Copyright   :  (c) Robert C. Taylor
License     :  Apache 2.0

Maintainer  :  r0wbrt@gmail.com
Stability   :  unstable 
Portability :  non-portable (C code relies on X86 execution model)

Library functions to calculate the FFT of lists of numbers and vectors of 
numbers. Additionally includes several functions to manipulate the data pre and
post FFT processing.
-}

{-# LANGUAGE ForeignFunctionInterface #-}

module OFDMRadar.DSP.FFT (
                              createFft
                            , createFftV
                            , cyclicShiftV
                            , cyclicShift
                            , cyclicMutateMatrix
                            , cyclicMutateMatrixV
                            ) where


                            
import qualified Data.Vector as V
import Data.Complex
import Foreign.Ptr
import Foreign.Marshal.Array 
import Foreign.Marshal.Alloc
import System.IO.Unsafe
import Foreign.Storable


-- | C function that calculates both the foward and backward fft transform over
--   an array of data.
foreign import ccall unsafe "fft" c_fft :: 
       Ptr (Complex Double) -- ^ Input signal that will be converted inplace
                            --   via the fft algorithm
    -> Ptr Double           -- ^ Location to store the Sin/Cos table. 
                            --   Should have size (n/2) - 1 
    -> Ptr Int              -- ^ Work Area used by the algorithm when doing
                            --   computation.
    -> Int                  -- ^ Direction of the transform. Note, 
                            --   renormalization of the output on inversion is 
                            --   done. (-1) for foward, 1 for backward.
    -> Int                  -- ^ Size of the FFT. MUST be a power of 2. 
                            --   Otherwise, the FFT algorithm in use will 
                            --   smash the stack and crash the program. 
    -> IO ()
         
-- | Performs an fft on the input data in the form of a list.
{-# NOINLINE fft #-}
fft:: Int -> Int -> [Complex Double] -> [Complex Double]
fft fftSize direction input 
    | inputLength /= fftSize  = error "Input length does not match fftSize"
    | fftSize < 1             = error "fftSize is invalid"
    | direction /= -1 && 
        direction /= 1        = error "Invalid FFT direction" 
    | otherwise               = unsafeDupablePerformIO $
    
    -- Convert the input into a C array
    withArray input $ 
        \cinput ->
        
        -- Convert the pre-computed vector coefficients into a c array
        allocaBytes (sizeOf (undefined::Double) * div fftSize 2) $ \ccoefs ->
        
                -- Convert the pre-computed IP coefficients into a c array
                allocaBytes (sizeOf (undefined::Int) *  ceiling ((2.0::Double) 
                    + sqrt(fromIntegral fftSize))) $ \cworkarea -> do
                    
                    --perform the fft using the c function
                    c_fft cinput ccoefs cworkarea direction fftSize
                    
                    -- Get the result
                    peekArray fftSize cinput
    
    where inputLength = length input
           
           
-- | Sets up a list based FFT.
{-# NOINLINE createFft #-}
createFft :: Int -> Int -> ([Complex Double] -> [Complex Double])
createFft 0 _ = const []
createFft 1 _ = take 1
createFft fftSize direction = fft fftSize direction


-- | Sets up a vector based FFT
{-# NOINLINE createFftV #-}
createFftV :: Int -> Int -> (V.Vector (Complex Double) -> 
                V.Vector (Complex Double))
createFftV 0 _ = const V.empty
createFftV 1 _ = V.take 1
createFftV fftSize direction = V.fromList . fft fftSize direction . V.toList

-- | Cyclic shifts a spectrum by a given number of FFT bins.
cyclicShift :: Double -> Int -> [Complex Double] -> [Complex Double]
cyclicShift shift size signal = zipWith (*) signal cyclicCoefs

    where cyclicCoefs = cycle [ cyclicCoef shift size i | i <- [0..(size - 1) ]]
    
-- | Cyclic shifts a vector spectrum by a given number of FFT bins.
cyclicShiftV :: Double -> Int -> V.Vector (Complex Double) 
                    -> V.Vector (Complex Double)
cyclicShiftV shift size signal = V.zipWith (*) signal cyclicCoefs
    
    where cyclicCoefs = V.generate (V.length signal) 
                            (\i -> cyclicCoef shift size (mod i size))
    

-- | Calculates the coefs to cyclic mutate a matrix
cyclicCoef :: Double -> Int -> Int -> Complex Double
cyclicCoef shift size pos = cis $ top / bottom

    where top = -2.0 * pi * shift * fromInteger(fromIntegral pos)
          
          bottom = fromIntegral size
          
          
-- | Cyclic shifts a matrix by a given shift
cyclicMutateMatrixV :: Double -> Int -> V.Vector (V.Vector (Complex Double)) -> 
                        V.Vector (V.Vector (Complex Double))
cyclicMutateMatrixV shift size = V.map multiplyColumn

    --Multiply each column entry with the cyclic shift coef
    where multiplyColumn = cyclicShiftV shift size
          

-- | Cyclic shifts a matrix by a given shift
cyclicMutateMatrix :: Double -> Int -> ([[Complex Double]] ->
                            [[Complex Double]])
cyclicMutateMatrix shift size = map multiplyColumn

    --Multiply each column entry with the cyclic shift coef
    where multiplyColumn = cyclicShift shift size
          
 