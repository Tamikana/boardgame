--
-- Copyright 2017 Azad Bolour
-- Licensed under GNU Affero General Public License v3.0 -
--   https://github.com/azadbolour/boardgame/blob/master/LICENSE.md
--

{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE NamedFieldPuns #-}
{-# LANGUAGE DisambiguateRecordFields #-}

module Main where

import System.Exit (die)
import Data.Either (isLeft)
import System.Environment (getArgs)
import Data.String.Here.Interpolated (iTrim)
import Control.Monad (forever)
import Control.Concurrent (forkIO, threadDelay)
import Control.Monad (when)
import Control.Monad.Except (ExceptT(ExceptT), runExceptT)
import Network.Wai (Middleware)
import qualified Network.Wai.Handler.Warp as Warp (run)
import Network.Wai.Middleware.Cors

import qualified Bolour.Util.PersistRunner as PersistRunner
import qualified Bolour.Util.HttpUtil as HttpUtil
import qualified Bolour.Util.Middleware as MyMiddleware
import Bolour.Util.MiscUtil (IOEither)
-- import qualified Bolour.Language.Domain.DictionaryCache as DictCache

import qualified BoardGame.Server.Domain.ServerConfig as ServerConfig
import BoardGame.Server.Domain.ServerConfig (ServerConfig, ServerConfig(ServerConfig))
import BoardGame.Server.Domain.GameEnv (GameEnv(..))
import qualified BoardGame.Server.Domain.GameEnv as GameEnv
import BoardGame.Server.Domain.GameError (GameError)
import qualified BoardGame.Server.Web.GameEndPoint as GameEndPoint (mkGameApp)
import qualified BoardGame.Server.Domain.GameCache as GameCache
import qualified BoardGame.Server.Service.GameTransformerStack as TransformerStack
import qualified BoardGame.Server.Service.GameService as GameService

-- | Timer interval for harvesting long-running games (considered abandoned).
harvestInterval :: Int
harvestInterval = 1000000 * 60 * 5 -- micros - reduce for testing
-- harvestInterval = 1000000 * 2 -- micros - increase for production

-- Terminology. The term 'environment' may mean a deployment environment
-- (DEV, TEST, PROD), or a reader monad environment. We use the
-- terms 'deployment environment' for the former and 'game environment'
-- (GameEnv) for the latter.


main :: IO ()
main = do
    serverConfig <- getServerConfig
    let ServerConfig {deployEnv, serverPort} = serverConfig
    eitherGameEnv <- runExceptT $ GameEnv.mkGameEnv serverConfig
    when (isLeft eitherGameEnv) $
      die $ "unable to initialize the application environment for server config " ++ show serverConfig
    let Right gameEnv = eitherGameEnv
    okEither <- prepareDb gameEnv
    when (isLeft okEither) $ do
      print $ show okEither
      die "database initialization failure"
    gameApp <- GameEndPoint.mkGameApp gameEnv
    forkIO $ longRunningGamesHarvester gameEnv
    print [iTrim|game server configuration ${serverConfig}|]
    print [iTrim|running Warp server on port '${serverPort}' for env '${deployEnv}'|]
    let logger = MyMiddleware.mkMiddlewareLogger deployEnv
    Warp.run serverPort $ logger $ myOptionsHandler $ simpleCors gameApp

-- Could not get this to work:
-- Warp.run serverPort $ logger $ MyMiddleware.gameCorsMiddleware $ simpleCors gameApp
-- TODO. simpleCors is a security risk. Fix.

getServerConfig :: IO ServerConfig
getServerConfig = do
    -- TODO. Use getOpt. from System.Console.GetOpt.
    args <- getArgs
    let maybeConfigPath = if null args then Nothing else Just $ head args
    print $ show maybeConfigPath
    ServerConfig.getServerConfig maybeConfigPath

prepareDb :: GameEnv -> IOEither GameError ()
prepareDb gameEnv = runExceptT $ TransformerStack.runDefault gameEnv GameService.prepareDb

-- TransformerStack.runDefault env stack

-- | Interceptor for HTTP OPTIONS methods.
myOptionsHandler :: Middleware
myOptionsHandler = MyMiddleware.optionsHandler HttpUtil.defaultOptionsHeaders

longRunningGamesHarvester :: GameEnv -> IO ()
longRunningGamesHarvester env =
  forever $ do
    threadDelay harvestInterval
    let ExceptT ioEither = TransformerStack.runDefault env GameService.timeoutLongRunningGames
    leftOrRight <- ioEither
    -- print "harvest of aged games completed"
    return ()


