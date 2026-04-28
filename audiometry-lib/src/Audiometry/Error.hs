module Audiometry.Error
    ( validateFrequency, validateIntensity, initSession
    ) where

import Audiometry.Types

validateFrequency :: Int -> Maybe Frequency
validateFrequency hz
    | hz `elem` standardFrequencies = Just (Frequency hz)
    | otherwise                     = Nothing
validateIntensity :: Int -> Maybe Intensity
validateIntensity db
    | db >= minIntensity && db <= maxIntensity = Just (Intensity db)
    | otherwise                               = Nothing
initSession :: Int -> Int -> Ear -> Maybe TestSession
initSession freqHz startdB ear = do
    freq      <- validateFrequency freqHz
    intensity <- validateIntensity startdB
    return TestSession
        { sessionEar = ear, sessionFrequency = freq, sessionCurrentdB = intensity
        , sessionSteps = [], sessionThresholds = [] }
