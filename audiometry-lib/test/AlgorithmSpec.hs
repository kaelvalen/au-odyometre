module AlgorithmSpec (spec) where

import Test.Hspec
import Audiometry.Types
import Audiometry.Algorithm
import Audiometry.Error
import Audiometry.Response

spec :: Spec
spec = do

    describe "stepDown" $ do
        it "50 dB'den 10 azaltir" $
            stepDown (Intensity 50) `shouldBe` Intensity 40
        it "0 dB'den 10 azaltir" $
            stepDown (Intensity 0) `shouldBe` Intensity (-10)

    describe "stepUp" $ do
        it "50 dB'ye 5 ekler" $
            stepUp (Intensity 50) `shouldBe` Intensity 55
        it "115 dB'ye 5 ekler" $
            stepUp (Intensity 115) `shouldBe` Intensity 120

    describe "nextIntensity" $ do
        it "Heard -> stepDown" $
            nextIntensity Heard (Intensity 60) `shouldBe` Intensity 50
        it "NotHeard -> stepUp" $
            nextIntensity NotHeard (Intensity 60) `shouldBe` Intensity 65

    describe "clampIntensity" $ do
        it "121 dB -> 120 dB" $
            clampIntensity (Intensity 121) `shouldBe` Intensity 120
        it "-11 dB -> -10 dB" $
            clampIntensity (Intensity (-11)) `shouldBe` Intensity (-10)
        it "50 dB degismez" $
            clampIntensity (Intensity 50) `shouldBe` Intensity 50

    describe "consecutiveHeardAt" $ do
        it "bos listede 0" $
            consecutiveHeardAt (Intensity 40) [] `shouldBe` 0
        it "3 ardisik Heard sayar" $
            let steps = replicate 3
                          (TestStep (Frequency 1000) (Intensity 40) RightEar Heard)
            in consecutiveHeardAt (Intensity 40) steps `shouldBe` 3
        it "farkli dB'de durur" $
            let steps = [ TestStep (Frequency 1000) (Intensity 40) RightEar Heard
                        , TestStep (Frequency 1000) (Intensity 50) RightEar Heard
                        ]
            in consecutiveHeardAt (Intensity 40) steps `shouldBe` 1

    describe "isThresholdReached" $ do
        it "3 Heard -> True" $
            let steps = replicate 3
                          (TestStep (Frequency 1000) (Intensity 40) RightEar Heard)
            in isThresholdReached (Intensity 40) steps `shouldBe` True
        it "2 Heard -> False" $
            let steps = replicate 2
                          (TestStep (Frequency 1000) (Intensity 40) RightEar Heard)
            in isThresholdReached (Intensity 40) steps `shouldBe` False

    describe "applyResponse" $ do
        it "adim sayisini 1 arttirir" $ do
            let Just s0 = initSession 1000 50 RightEar
                step    = TestStep (Frequency 1000) (Intensity 50) RightEar NotHeard
                s1      = applyResponse step s0
            length (sessionSteps s1) `shouldBe` 1
        it "Heard sonrasi dB azalir" $ do
            let Just s0 = initSession 1000 50 RightEar
                step    = TestStep (Frequency 1000) (Intensity 50) RightEar Heard
                s1      = applyResponse step s0
            sessionCurrentdB s1 `shouldBe` Intensity 40
        it "NotHeard sonrasi dB artar" $ do
            let Just s0 = initSession 1000 50 RightEar
                step    = TestStep (Frequency 1000) (Intensity 50) RightEar NotHeard
                s1      = applyResponse step s0
            sessionCurrentdB s1 `shouldBe` Intensity 55

    describe "validateFrequency" $ do
        it "1000 Hz gecerli" $
            validateFrequency 1000 `shouldBe` Just (Frequency 1000)
        it "300 Hz gecersiz" $
            validateFrequency 300 `shouldBe` Nothing
        it "tum standart frekanslar gecerli" $
            all (\f -> validateFrequency f /= Nothing) [250,500,1000,2000,4000,8000]
                `shouldBe` True

    describe "validateIntensity" $ do
        it "50 dB gecerli" $
            validateIntensity 50 `shouldBe` Just (Intensity 50)
        it "130 dB gecersiz" $
            validateIntensity 130 `shouldBe` Nothing
        it "-10 dB sinir gecerli" $
            validateIntensity (-10) `shouldBe` Just (Intensity (-10))
        it "120 dB sinir gecerli" $
            validateIntensity 120 `shouldBe` Just (Intensity 120)
        it "-11 dB gecersiz" $
            validateIntensity (-11) `shouldBe` Nothing

    describe "initSession" $ do
        it "gecerli parametrelerle session uretir" $
            initSession 1000 40 RightEar `shouldSatisfy` (/= Nothing)
        it "gecersiz frekansla Nothing" $
            initSession 300 40 RightEar `shouldBe` Nothing
        it "gecersiz siddetle Nothing" $
            initSession 1000 130 RightEar `shouldBe` Nothing

    describe "parseResponse" $ do
        it "RESPONSE -> Just Heard" $
            parseResponse "RESPONSE" `shouldBe` Just Heard
        it "TIMEOUT -> Just NotHeard" $
            parseResponse "TIMEOUT" `shouldBe` Just NotHeard
        it "bilinmeyen -> Nothing" $
            parseResponse "GARBAGE" `shouldBe` Nothing

    describe "validResponses" $ do
        it "Nothing degerleri atar" $
            validResponses [Just Heard, Nothing, Just NotHeard]
                `shouldBe` [Heard, NotHeard]
        it "tumu gecersizse bos liste" $
            validResponses [Nothing, Nothing] `shouldBe` []

    describe "processMessages" $ do
        it "RESPONSE mesajini Heard adima donusturur" $ do
            let steps = processMessages (Frequency 1000) (Intensity 40) RightEar ["RESPONSE"]
            length steps `shouldBe` 1
            stepResponse (head steps) `shouldBe` Heard
        it "gecersiz mesajlari atar" $ do
            let steps = processMessages (Frequency 1000) (Intensity 40) RightEar
                            ["RESPONSE", "INVALID", "TIMEOUT"]
            length steps `shouldBe` 2

    describe "foldSession" $ do
        it "bos liste session'i degistirmez" $ do
            let Just s0 = initSession 1000 40 RightEar
            foldSession s0 [] `shouldBe` s0
        it "3 adim -> session'da 3 adim" $ do
            let Just s0 = initSession 1000 40 RightEar
                steps   = replicate 3
                            (TestStep (Frequency 1000) (Intensity 40) RightEar Heard)
                s3      = foldSession s0 steps
            length (sessionSteps s3) `shouldBe` 3
