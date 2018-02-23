module BoardGame.Server.Domain.HopelessBlanksSpec where

import Test.Hspec

import qualified BoardGame.Server.Domain.WordDictionary as Dict
import qualified BoardGame.Server.Domain.StripMatcher as StripMatcher
import qualified BoardGame.Server.Domain.Board as Board
import BoardGame.Server.Domain.Board (Board, Board(Board))
import BoardGame.Server.Domain.Tray (Tray, Tray(Tray))
import Bolour.Grid.GridValue (GridValue, GridValue(GridValue))
import BoardGame.Common.Domain.GridPiece
import BoardGame.Common.Domain.Piece (Piece, Piece(Piece))
import Bolour.Grid.Point (Point, Point(Point))
import qualified Bolour.Grid.Point as Axis

trayCapacity :: Int
trayCapacity = 3
dimension :: Int
dimension = 3

emptyBoard :: Board
emptyBoard = Board.mkEmptyBoard dimension

tray :: Tray
tray = Tray trayCapacity [] -- no need for pieces in this test

myWords = ["AND", "TAN"]
dictionary = Dict.mkDictionary "en" myWords 2

gridPieces :: [GridPiece]
gridPieces = [
    GridValue (Piece 'A' "0") (Point 2 0),
    GridValue (Piece 'N' "1") (Point 2 1),
    GridValue (Piece 'D' "2") (Point 2 2),
    GridValue (Piece 'T' "3") (Point 0 1),
    GridValue (Piece 'A' "4") (Point 1 1)
  ]

board = Board.setN emptyBoard gridPieces

spec :: Spec
spec = do
  describe "hopeless blanks" $
    it "find hopeless blanks" $ do
      let hopeless = StripMatcher.hopelessBlankPoints board dictionary trayCapacity
      print hopeless
      let hopelessX = StripMatcher.hopelessBlankPointsForAxis board dictionary trayCapacity Axis.X
      print hopelessX
      let hopelessY = StripMatcher.hopelessBlankPointsForAxis board dictionary trayCapacity Axis.Y
      print hopelessY
      -- Dict.isWord dictionary "TEST" `shouldBe` True
  describe "masked words" $
    it "compute masked words" $ do
      Dict.isMaskedWord dictionary " A " `shouldBe` True
      Dict.isMaskedWord dictionary "  D" `shouldBe` True
  describe "playable strips with blanks" $
    it "playableEnclosingStripsOfBlankPoints" $ do
      let playableX = Board.playableEnclosingStripsOfBlankPoints board Axis.X trayCapacity
      sequence_ $ print <$> playableX
      let playableY = Board.playableEnclosingStripsOfBlankPoints board Axis.Y trayCapacity
      sequence_ $ print <$> playableY