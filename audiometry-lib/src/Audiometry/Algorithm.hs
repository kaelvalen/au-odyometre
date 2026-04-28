module Audiometry.Algorithm
    ( stepDown, stepUp, nextIntensity, clampIntensity
    , consecutiveHeardAt, isThresholdReached, applyResponse
    ) where

import Audiometry.Types

stepDown :: Intensity -> Intensity
stepDown (Intensity db) = Intensity (db - 10)
stepUp :: Intensity -> Intensity
stepUp (Intensity db) = Intensity (db + 5)
nextIntensity :: Response -> Intensity -> Intensity
nextIntensity Heard    = stepDown
nextIntensity NotHeard = stepUp
clampIntensity :: Intensity -> Intensity
clampIntensity (Intensity db) =
    Intensity (max minIntensity (min maxIntensity db))
consecutiveHeardAt :: Intensity -> [TestStep] -> Int
consecutiveHeardAt target =
    length . takeWhile (\s -> stepResponse s == Heard && stepIntensity s == target)
isThresholdReached :: Intensity -> [TestStep] -> Bool
isThresholdReached i steps = consecutiveHeardAt i steps >= 3
applyResponse :: TestStep -> TestSession -> TestSession
applyResponse step session =
    let updatedSteps = step : sessionSteps session
        currentdB    = stepIntensity step
        hit          = isThresholdReached currentdB updatedSteps
        newT         = Threshold (sessionFrequency session) currentdB (sessionEar session)
        newTs        = if hit then newT : sessionThresholds session else sessionThresholds session
        nextdB       = clampIntensity (nextIntensity (stepResponse step) currentdB)
    in session { sessionSteps = updatedSteps, sessionCurrentdB = nextdB, sessionThresholds = newTs }
