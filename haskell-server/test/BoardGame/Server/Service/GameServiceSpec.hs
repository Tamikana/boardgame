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
import Control.Monad.Except (ExceptT, runExceptT)
import Control.Monad.Reader (runReaderT)
import Control.Monad.IO.Class (liftIO)
import Control.Monad.Log (runLoggingT)

import Bolour.Util.DbUtil (makePool)
import BoardGame.Server.Domain.GameConfig (Config(..), DeployEnv(..))
import qualified BoardGame.Server.Domain.GameConfig as Config
import qualified BoardGame.Server.Domain.GameConfig as ServerParameters
import BoardGame.Common.Domain.Player(Player, Player(Player))
import BoardGame.Common.Domain.Piece (Piece(Piece))
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
import qualified Bolour.Util.StaticTextFileCache as FileCache
import BoardGame.Server.Web.WebTestFixtures (
      thePlayer
    , params
    , centerGridPiece
  )
import qualified BoardGame.Server.Domain.DictionaryCache as DictCache

initTest :: IO GameEnv -- TODO. Should be MonadIO m.
initTest = do
  -- TODO. Use getServerParameters and provide a config file for test.
  let serverParameters = Config.defaultServerParameters
      ServerParameters.ServerParameters {maxActiveGames} = serverParameters
  thePool <- makePool serverParameters
  config <- Config.mkConfig serverParameters thePool
  cleanupDb config
  cache <- GameCache.mkGameCache maxActiveGames
  -- dictionaryCache <- FileCache.mkCache 100 (toUpper <$>)
  dictionaryCache <- DictCache.mkCache "" 100
  return $ GameEnv config cache dictionaryCache


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
  env <- initTest
  runner' env stack

spec :: Spec
spec = do
  describe "start a game" $
    it "starts game" $
      do -- IO
        userTray <- runner'' $ do -- GameTransformerStack
          addPlayerService $ Player thePlayer
          Game {trays} <- startGameService params [] [] []
          return $ trays !! 0
        length (Tray.pieces userTray) `shouldSatisfy` (== 12)

  describe "commits a play" $
    it "commit a play" $
      do -- IO
        gridPiece <- liftIO $ centerGridPiece 'E'
        includeUserPieces <- sequence [Piece.mkPiece 'B', Piece.mkPiece 'T'] -- Allow the word 'BET'
        refills <- runner'' $ do -- GameTransformerStack
          addPlayerService $ Player thePlayer
          Game {gameId, board, trays} <- startGameService params [gridPiece] includeUserPieces []
          let trayPieces = Tray.pieces (trays !! 0)
              theOnlyGridPiece = head $ Board.getGridPieces board
              playPieces = mkInitialPlayPieces theOnlyGridPiece trayPieces
          -- TODO. add satisfiesRight
          commitPlayService gameId playPieces -- refills
        length refills `shouldBe` 2

  describe "make machine play" $
    it "make machine play" $
      do -- IO
        word <- runner'' $ do
          addPlayerService $ Player thePlayer
          Game {gameId} <- startGameService params [] [] []
          wordPlayPieces <- machinePlayService gameId
          let word = Play.playToWord $ Play wordPlayPieces
          return word
        length word `shouldSatisfy` (> 1)

  describe "swap a piece" $
    it "swap a piece" $
      do
        value <- runner'' $ do
          addPlayerService $ Player thePlayer
          Game {gameId, trays} <- startGameService params [] [] []
          let userTray = trays !! 0
              piece = head (Tray.pieces userTray)
          -- TODO satisfiesRight
          (Piece {value}) <- swapPieceService gameId piece
          return value
        value `shouldSatisfy` isUpper

  describe "get play details for a game" $
    it "get play details for a game" $
      do
        env <- initTest
        gridPiece <- liftIO $ centerGridPiece 'E'
        includeUserPieces <- sequence [Piece.mkPiece 'B', Piece.mkPiece 'T'] -- Allow the word 'BET'

        eitherPlayInfoList <- runner env $ do
          addPlayerService $ Player thePlayer
          Game {gameId, board, trays} <- startGameService params [gridPiece] includeUserPieces []

          let trayPieces = Tray.pieces (trays !! 0)
              theOnlyGridPiece = head $ Board.getGridPieces board
              playPieces = mkInitialPlayPieces theOnlyGridPiece trayPieces
          refills <- commitPlayService gameId playPieces
          -- TODO. Need to update tray here.
          machinePlayService gameId

          let piece = head refills
          (Piece {value}) <- swapPieceService gameId piece

          getGamePlayDetailsService gameId
        case eitherPlayInfoList of
          Left err -> do
            print err
            -- TODO. How do you fail?
            1 `shouldBe` 2
          Right playInfoList -> do
            print playInfoList
            length playInfoList `shouldBe` 3



