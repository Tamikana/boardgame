--
-- Copyright 2017 Azad Bolour
-- Licensed under GNU Affero General Public License v3.0 -
--   https://github.com/azadbolour/boardgame/blob/master/LICENSE.md
--

{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DeriveAnyClass #-}

module BoardGame.Common.Message.GameDto (
  GameDto(..)
  )
  where

import GHC.Generics (Generic)
import Data.Aeson (FromJSON, ToJSON)
import Control.DeepSeq (NFData)

import BoardGame.Common.Domain.GameParams (GameParams)
import BoardGame.Common.Domain.Point (Height, Width)
import BoardGame.Common.Domain.Piece (Piece)
import BoardGame.Common.Domain.GridValue (GridValue)

-- | Data transfer object for a game.
--   The machine tray is excluded -
--   we don't want to reveal the machine's hand to client programs.
data GameDto = GameDto {
    gameId :: String          -- ^ The unique identifier of the game.
  , gameParams :: GameParams
  , gridPieces :: [GridValue Piece]   -- ^ The pieces in play and their positions.
  , trayPieces :: [Piece]     -- ^ The pieces on the user tray.
}
  deriving (Eq, Show, Generic, NFData)

instance FromJSON GameDto
instance ToJSON GameDto



