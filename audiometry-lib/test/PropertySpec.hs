{-# LANGUAGE ScopedTypeVariables #-}
module PropertySpec (spec) where

import Test.Hspec
import Test.QuickCheck
import Audiometry.Types
import Audiometry.Algorithm
import Audiometry.Error
import Audiometry.Response

instance Arbitrary Intensity where
    arbitrary = Intensity <$> choose (-10, 120)
instance Arbitrary Frequency where
    arbitrary = Frequency <$> elements [250,500,1000,2000,4000,8000]
instance Arbitrary Ear where
    arbitrary = elements [LeftEar, RightEar]
instance Arbitrary Response where
    arbitrary = elements [Heard, NotHeard]
instance Arbitrary TestStep where
    arbitrary = TestStep <$> arbitrary <*> arbitrary <*> arbitrary <*> arbitrary

spec :: Spec
spec = do
    describe "nextIntensity" $ do
        it "Heard -> azalir" $ property $ \(Intensity db) ->
            db > minIntensity ==> nextIntensity Heard (Intensity db) < Intensity db
        it "NotHeard -> artar" $ property $ \(Intensity db) ->
            db < maxIntensity ==> nextIntensity NotHeard (Intensity db) > Intensity db
    describe "clampIntensity" $ do
        it "her zaman [-10,120] araliginda" $ property $ \(Intensity db) ->
            let Intensity c = clampIntensity (Intensity db) in c >= minIntensity && c <= maxIntensity
        it "gecerli aralikta degismez" $ property $ \(Intensity db) ->
            db >= minIntensity && db <= maxIntensity ==>
                clampIntensity (Intensity db) == Intensity db
    describe "applyResponse" $
        it "her adim buyutur" $ property $ \step ->
            let Just s0 = initSession 1000 40 RightEar
            in length (sessionSteps (applyResponse step s0)) == 1
    describe "validateIntensity" $ do
        it "gecerli aralik" $ property $ \db ->
            (db >= minIntensity && db <= maxIntensity) ==> validateIntensity db /= Nothing
        it "gecersiz aralik" $ property $ \db ->
            (db < minIntensity || db > maxIntensity) ==> validateIntensity db == Nothing
    describe "validateFrequency" $ do
        it "standart gecerli" $ property $ \f ->
            f `elem` [250,500,1000,2000,4000,8000::Int] ==> validateFrequency f /= Nothing
        it "standart olmayan gecersiz" $ property $ \f ->
            f `notElem` [250,500,1000,2000,4000,8000::Int] ==> validateFrequency f == Nothing
    describe "validResponses" $
        it "uzunluk <= giris" $ property $ \(msgs :: [Maybe Response]) ->
            length (validResponses msgs) <= length msgs
    describe "foldSession" $ do
        it "n adim" $ property $ \steps ->
            let Just s0 = initSession 1000 40 RightEar
            in length (sessionSteps (foldSession s0 (steps :: [TestStep]))) == length steps
        it "bos degismez" $
            let Just s0 = initSession 1000 40 RightEar in foldSession s0 [] == s0
