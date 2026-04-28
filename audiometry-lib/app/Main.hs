module Main where

import Audiometry.Types
import Audiometry.Algorithm
import Audiometry.Error

-- | JSON string içinde "key":N değerini bul.
extractInt :: String -> String -> Maybe Int
extractInt key s =
  case splitOn ("\"" ++ key ++ "\":") s of
    [_, rest] ->
      let digits = takeWhile (\c -> c == '-' || (c >= '0' && c <= '9'))
                              (dropWhile (== ' ') rest)
      in if null digits then Nothing else Just (read digits)
    _ -> Nothing

-- | JSON string içinde "key":"val" değerini bul.
extractStr :: String -> String -> Maybe String
extractStr key s =
  case splitOn ("\"" ++ key ++ "\":\"") s of
    [_, rest] -> Just (takeWhile (/= '"') rest)
    _         -> Nothing

splitOn :: String -> String -> [String]
splitOn _ "" = [""]
splitOn sep str
  | take n str == sep = "" : splitOn sep (drop n str)
  | otherwise =
      case splitOn sep (tail str) of
        (x:xs) -> (head str : x) : xs
        []     -> [[head str]]
  where n = length sep

parseEar :: String -> Maybe Ear
parseEar "right" = Just RightEar
parseEar "left"  = Just LeftEar
parseEar _       = Nothing

parseResponse :: String -> Maybe Response
parseResponse "HEARD"     = Just Heard
parseResponse "NOT_HEARD" = Just NotHeard
parseResponse _           = Nothing

parseRequest :: String -> Maybe (Int, Int, Ear, Response)
parseRequest s = do
  freq <- extractInt "frequency" s
  db   <- extractInt "intensity" s
  earS <- extractStr "ear"       s
  ear  <- parseEar earS
  rspS <- extractStr "response"  s
  rsp  <- parseResponse rspS
  return (freq, db, ear, rsp)

encodeThreshold :: Threshold -> String
encodeThreshold t =
  "{\"frequency\":" ++ show (unFrequency (threshFrequency t)) ++
  ",\"intensity\":" ++ show (unIntensity  (threshIntensity t)) ++
  ",\"ear\":\""     ++ (case threshEar t of RightEar -> "right"; LeftEar -> "left") ++ "\"}"

encodeResult :: Intensity -> Bool -> [Threshold] -> String
encodeResult (Intensity next) reached thresholds =
  "{\"nextIntensity\":" ++ show next ++
  ",\"thresholdReached\":" ++ (if reached then "true" else "false") ++
  ",\"thresholds\":[" ++
    foldl (\acc t -> (if null acc then "" else acc ++ ",") ++ encodeThreshold t) "" thresholds
  ++ "]}"

main :: IO ()
main = do
  input <- getContents
  let output = case parseRequest input of
        Nothing -> "{\"error\":\"invalid_json\"}"
        Just (freqHz, db, ear, resp) ->
          case initSession freqHz db ear of
            Left (IntensityOutOfRange _) -> "{\"error\":\"intensity_out_of_range\"}"
            Left (InvalidFrequency _)    -> "{\"error\":\"invalid_frequency\"}"
            Right session ->
              let step    = TestStep (sessionFrequency session)
                                     (sessionCurrentdB  session)
                                     (sessionEar        session)
                                     resp
                  updated = applyResponse step session
                  reached = not . null $ sessionThresholds updated
              in encodeResult (sessionCurrentdB updated) reached (sessionThresholds updated)
  putStrLn output
