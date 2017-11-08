--
-- Copyright 2017 Azad Bolour
-- Licensed under GNU Affero General Public License v3.0 -
--   https://github.com/azadbolour/boardgame/blob/master/LICENSE.md
--

{-# LANGUAGE NamedFieldPuns #-}
{-# LANGUAGE DisambiguateRecordFields #-}
{-# LANGUAGE RecordWildCards #-}

module BoardGame.Server.Service.GameServiceSpec (
    spec
  ) where

import Test.Hspec
import Data.Char (isUpper, toUpper)
import Data.Maybe (fromJust)
import Data.List
import Control.Monad.Except (ExceptT, runExceptT)
import Control.Monad.Reader (runReaderT)
import Control.Monad.IO.Class (liftIO)
import Control.Monad.Log (runLoggingT)

import qualified Bolour.Util.PersistRunner as PersistRunner
import BoardGame.Server.Domain.ServerConfig (ServerConfig, ServerConfig(ServerConfig), DeployEnv(..))
import qualified BoardGame.Server.Domain.ServerConfig as ServerConfig
import BoardGame.Common.Domain.Player(Player, Player(Player))
import BoardGame.Common.Domain.Piece (Piece(Piece))
import BoardGame.Common.Domain.GridValue (GridValue, GridValue(GridValue))
import qualified BoardGame.Common.Domain.GridValue as GridValue
import qualified BoardGame.Common.Domain.GridPiece as GridPiece
import BoardGame.Common.Domain.Point (Point, Point(Point))
import qualified BoardGame.Common.Domain.Point as Point
import BoardGame.Common.Domain.PlayPiece (PlayPiece, PlayPiece(PlayPiece))
import BoardGame.Server.Domain.GameCache as GameCache
import BoardGame.Server.Service.GameDao (cleanupDb)
import BoardGame.Server.Domain.GameError
import BoardGame.Server.Domain.Game (Game(Game))
import BoardGame.Server.Domain.Play (Play(Play))
import BoardGame.Server.Domain.GameEnv (GameEnv, GameEnv(GameEnv))
import BoardGame.Server.Service.GameTransformerStack

import qualified BoardGame.Server.Domain.Play as Play (playToWord)
import qualified BoardGame.Common.Domain.Piece as Piece
import qualified BoardGame.Server.Domain.Tray as Tray
import qualified BoardGame.Server.Domain.Game as Game
import qualified BoardGame.Server.Domain.Board as Board
import BoardGame.Server.Service.GameService (
    addPlayerService
  , commitPlayService
  , startGameService
  , machinePlayService
  , swapPieceService
  , getGamePlayDetailsService
  )
-- TODO. Should not depend on higher level module.
import BoardGame.Util.TestUtil (mkInitialPlayPieces)
import qualified BoardGame.Server.Service.ServiceTestFixtures as Fixtures
import qualified BoardGame.Server.Domain.DictionaryCache as DictCache

printx :: String -> ExceptT GameError IO ()
printx s = do
  liftIO $ print s
  return ()

-- TODO. Annotate spec do statements with the demystified type of their monad.
-- TODO. Factor out common test functions to a base type class.

-- TODO. Test with games of dimension 1 as a boundary case.

runner :: GameEnv -> GameTransformerStack a -> IO (Either GameError a)
runner env stack = runExceptT $ flip runLoggingT printx $ runReaderT stack env

-- TODO. How to catch Left - print error and return gracefully.
runner' env stack = do
  Right val <- runner env stack
  return val

runner'' :: GameTransformerStack a -> IO a
runner'' stack = do
  env <- Fixtures.initTest
  runner' env stack

spec :: Spec
spec = do
  describe "start a game" $
    it "starts game" $
      do -- IO
        userTray <- runner'' $ do -- GameTransformerStack
          addPlayerService $ Player Fixtures.thePlayer
          (Game {trays}, maybePlayPieces) <- startGameService Fixtures.gameParams [] [] []
          return $ trays !! 0
        length (Tray.pieces userTray) `shouldSatisfy` (== Fixtures.testTrayCapacity)

  describe "commits a play" $
    it "commit a play" $
      do -- IO
        mPieces <- sequence [Piece.mkPiece 'B', Piece.mkPiece 'E', Piece.mkPiece 'T'] -- Allow the word 'BET'
        uPieces <- sequence [Piece.mkPiece 'S', Piece.mkPiece 'T', Piece.mkPiece 'Z'] -- Allow the word 'SET' across.

        refills <- runner'' $ do -- GameTransformerStack
          addPlayerService $ Player Fixtures.thePlayer
          (Game {gameId, board, trays}, _) <- startGameService Fixtures.gameParams [] uPieces mPieces
          let gridPieces = Board.getGridPieces board
              GridValue {value = piece, point = centerPoint} =
                fromJust $ find (\gridPiece -> GridPiece.gridLetter gridPiece == 'E') gridPieces
              Point {row, col} = centerPoint
          let userPiece0:userPiece1:_ = uPieces
              _:machinePiece1:_ = mPieces
              playPieces = [
                  PlayPiece userPiece0 (Point (row - 1) col) True
                , PlayPiece machinePiece1 (Point row col) False
                , PlayPiece userPiece1 (Point (row + 1) col) True
                ]
          commitPlayService gameId playPieces -- refills
        length refills `shouldBe` 2

  describe "make machine play" $
    it "make machine play" $
      do -- IO
        word <- runner'' $ do
          addPlayerService $ Player Fixtures.thePlayer
          (Game {gameId}, _) <- startGameService Fixtures.gameParams [] [] []
          wordPlayPieces <- machinePlayService gameId
          let word = Play.playToWord $ Play wordPlayPieces
          return word
        print word
        length word `shouldSatisfy` (> 1)

  describe "swap a piece" $
    it "swap a piece" $
      do
        value <- runner'' $ do
          addPlayerService $ Player Fixtures.thePlayer
          (Game {gameId, trays}, _) <- startGameService Fixtures.gameParams [] [] []
          let userTray = trays !! 0
              piece = head (Tray.pieces userTray)
          -- TODO satisfiesRight
          (Piece {value}) <- swapPieceService gameId piece
          return value
        value `shouldSatisfy` isUpper

-- TODO. Clean up and reinstate the following test according to the above procedure to start a game.

--   describe "get play details for a game" $
--     it "get play details for a game" $
--       do
--         env <- Fixtures.initTest
--         gridPiece <- liftIO $ Fixtures.centerGridPiece 'E'
--         includeUserPieces <- sequence [Piece.mkPiece 'B', Piece.mkPiece 'T'] -- Allow the word 'BET'
--
--         eitherPlayInfoList <- runner env $ do
--           addPlayerService $ Player Fixtures.thePlayer
--           -- play 1 - play in start - the first machine play
--           (Game {gameId, board, trays}, _) <- startGameService Fixtures.gameParams [gridPiece] includeUserPieces []
--           let trayPieces = Tray.pieces (trays !! 0)
--               theOnlyGridPiece = head $ Board.getGridPieces board
--               playPieces = mkInitialPlayPieces theOnlyGridPiece trayPieces
--           -- play 2 - user play
--           refills <- commitPlayService gameId playPieces
--           -- TODO. Need to update tray here.
--           -- play 3
--           machinePlayService gameId
--
--           let piece = head refills
--           -- play 4
--           (Piece {value}) <- swapPieceService gameId piece
--
--           getGamePlayDetailsService gameId
--         case eitherPlayInfoList of
--           Left err -> do
--             print err
--             -- TODO. How do you fail?
--             1 `shouldBe` 2
--           Right playInfoList -> do
--             print playInfoList
--             length playInfoList `shouldBe` 4

