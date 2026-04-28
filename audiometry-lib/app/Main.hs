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
  action <- extractStr "action" s
  if action /= "applyResponse" then Nothing else Just ()
  freq <- extractInt "frequency" s
  db   <- extractInt "intensity" s
  earS <- extractStr "ear"       s
  ear  <- parseEar earS
  rspS <- extractStr "response"  s
  rsp  <- parseResponse rspS
  return (freq, db, ear, rsp)

encodeThreshold :: Threshold -> String
encodeThreshold t =
  let Frequency f = threshFrequency t
      Intensity i = threshIntensity t
  in "{\"frequency\":" ++ show f ++
     ",\"intensity\":" ++ show i ++
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
          case (validateFrequency freqHz, validateIntensity db) of
            (Nothing, _) -> "{\"error\":\"invalid_frequency\"}"
            (_, Nothing) -> "{\"error\":\"intensity_out_of_range\"}"
            (Just freq, Just intensity) ->
              let session0 =
                    TestSession
                      { sessionEar = ear
                      , sessionFrequency = freq
                      , sessionCurrentdB = intensity
                      , sessionSteps = []
                      , sessionThresholds = []
                      }
                  step =
                    TestStep
                      (sessionFrequency session0)
                      (sessionCurrentdB  session0)
                      (sessionEar        session0)
                      resp
                  updated  = applyResponse step session0
                  reached  = length (sessionThresholds updated) > length (sessionThresholds session0)
              in encodeResult (sessionCurrentdB updated) reached (sessionThresholds updated)
  putStrLn output
