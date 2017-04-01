--Copyright Robert C. Taylor - All Rights Reserved

{- |
Module      :  ChirpTx
Description :  Program to generate radar chirps
Copyright   :  (c) Robert C. Taylor
License     :  Apache 2.0

Maintainer  :  r0wbrt@gmail.com
Stability   :  unstable 
Portability :  portable 

This program generates linear chirps for chirp based pulse compression radar.
-}
module Shared.ChirpTx where


import qualified Shared.ChirpCommon as ChirpCommon
import System.Console.GetOpt as GetOpt
import qualified YASDRR.SDR.ChirpRadar as Chirp
import qualified Data.ByteString as B
import qualified Shared.CommandLine as CL
import qualified Shared.IO as SIO
import System.IO
import System.Exit


processCommandInput :: GetOpt.ArgOrder (ChirpCommon.ChirpOptions -> IO ChirpCommon.ChirpOptions) -> [String] ->  (IO ChirpCommon.ChirpOptions, [String], [String])
processCommandInput argOrder arguments = (CL.processInput ChirpCommon.startOptions actions, extra, errors)
    where (actions, extra, errors) = GetOpt.getOpt argOrder ChirpCommon.chirpRadarTxOptions arguments


chirpTxMainIO :: [String] -> IO ()
{-# ANN module "HLint: ignore Use :" #-}
chirpTxMainIO arguments =
    case processCommandInput GetOpt.RequireOrder arguments of
        (programSettingsIO, [], []) -> do
              
              programSettings <- programSettingsIO
              
              hSetBinaryMode stdout True 
              
              chirpTxMain programSettings
              
              hSetBinaryMode stdout False 
              
              _ <- ChirpCommon.optCloseOutput programSettings
              
              exitSuccess
        (_, _, errors) -> do
              hPutStrLn stderr $ unlines $ ["Invalid input supplied"] ++ errors
              exitFailure


chirpTxMain :: ChirpCommon.ChirpOptions -> IO ()
{-# ANN module "HLint: ignore Use :" #-}
chirpTxMain programSettings = do
    
    let chirpLength = ChirpCommon.calculateSignalLength programSettings
    let repetitions = ChirpCommon.optRepetitions programSettings
    
    let outputFormat = ChirpCommon.optOutputSampleFormat programSettings
    
    let chirpSettings = Chirp.ChirpRadarSettings
            { Chirp.optStartFrequency = ChirpCommon.optStartFrequency programSettings
            , Chirp.optEndFrequency = ChirpCommon.optEndFrequency programSettings
            , Chirp.optFrequencyShift = ChirpCommon.optFrequencyShift programSettings
            , Chirp.optSampleRate = ChirpCommon.optSampleRate programSettings
            , Chirp.optRiseTime = chirpLength
            , Chirp.optSilenceLength = ChirpCommon.optSilenceLength programSettings
            , Chirp.optSilenceTruncateLength = ChirpCommon.optSilenceTruncateLength programSettings
            , Chirp.optAmplitude = ChirpCommon.optAmplitude programSettings
            , Chirp.optChirpWindow = ChirpCommon.optChirpWindow programSettings
            , Chirp.optSignalWindow = ChirpCommon.optSignalWindow programSettings
            }
    
    let finalSignal = SIO.serializeOutput outputFormat $ Chirp.chirpTx chirpSettings
    
    let writer = ChirpCommon.optOutputWriter programSettings
    
    writeOutput writer finalSignal repetitions


writeOutput :: (B.ByteString -> IO ()) -> B.ByteString -> Int -> IO ()
writeOutput _ _ 0 = return ()
writeOutput writer signal count = do
    
    let newCount = if count /= -1 then count - 1 else -1
    
    writer signal
    writeOutput writer signal newCount 
