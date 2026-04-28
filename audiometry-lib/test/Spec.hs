module Main (main) where

import Test.Hspec
import qualified AlgorithmSpec
import qualified PropertySpec

main :: IO ()
main = hspec $ do
    describe "Unit Testler"     AlgorithmSpec.spec
    describe "Property Testler" PropertySpec.spec
