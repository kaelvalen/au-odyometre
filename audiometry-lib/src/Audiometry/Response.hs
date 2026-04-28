module Audiometry.Response
    ( parseResponse, parseResponses, validResponses
    , toTestSteps, processMessages, foldSession
    ) where

import Audiometry.Types
import Audiometry.Algorithm (applyResponse)

parseResponse :: String -> Maybe Response
parseResponse "RESPONSE" = Just Heard
parseResponse "TIMEOUT"  = Just NotHeard
parseResponse _          = Nothing
parseResponses :: [String] -> [Maybe Response]
parseResponses = map parseResponse
validResponses :: [Maybe Response] -> [Response]
validResponses = foldr (\x acc -> case x of Just r -> r:acc; Nothing -> acc) []
toTestSteps :: Frequency -> Intensity -> Ear -> [Response] -> [TestStep]
toTestSteps freq intensity ear = map (\r -> TestStep freq intensity ear r)
processMessages :: Frequency -> Intensity -> Ear -> [String] -> [TestStep]
processMessages freq intensity ear =
    toTestSteps freq intensity ear . validResponses . parseResponses
foldSession :: TestSession -> [TestStep] -> TestSession
foldSession = foldl (flip applyResponse)
