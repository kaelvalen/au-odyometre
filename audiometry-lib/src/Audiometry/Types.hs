module Audiometry.Types
    ( Frequency(..)
    , Intensity(..)
    , Ear(..)
    , Response(..)
    , TestStep(..)
    , Threshold(..)
    , TestSession(..)
    , standardFrequencies
    , minIntensity
    , maxIntensity
    ) where

newtype Frequency = Frequency Int
    deriving (Show, Eq, Ord)
newtype Intensity = Intensity Int
    deriving (Show, Eq, Ord)
data Ear = LeftEar | RightEar
    deriving (Show, Eq, Ord, Enum, Bounded)
data Response = Heard | NotHeard
    deriving (Show, Eq, Ord, Enum, Bounded)
data TestStep = TestStep
    { stepFrequency :: Frequency
    , stepIntensity :: Intensity
    , stepEar       :: Ear
    , stepResponse  :: Response
    } deriving (Show, Eq)
data Threshold = Threshold
    { threshFrequency :: Frequency
    , threshIntensity :: Intensity
    , threshEar       :: Ear
    } deriving (Show, Eq)
data TestSession = TestSession
    { sessionEar        :: Ear
    , sessionFrequency  :: Frequency
    , sessionCurrentdB  :: Intensity
    , sessionSteps      :: [TestStep]
    , sessionThresholds :: [Threshold]
    } deriving (Show, Eq)

standardFrequencies :: [Int]
standardFrequencies = [250, 500, 1000, 2000, 4000, 8000]
minIntensity :: Int
minIntensity = -10
maxIntensity :: Int
maxIntensity = 120
