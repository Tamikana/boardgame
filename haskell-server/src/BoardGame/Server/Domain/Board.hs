--
-- Copyright 2017 Azad Bolour
-- Licensed under GNU Affero General Public License v3.0 -
--   https://github.com/azadbolour/boardgame/blob/master/LICENSE.md
--

{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE NamedFieldPuns #-}
{-# LANGUAGE DisambiguateRecordFields #-}
{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE FlexibleContexts #-}

module BoardGame.Server.Domain.Board (
    Board
  , Board(Board)
  , Board(dimension)
  , Board(grid)
  , mkBoard
  , mkEmptyBoard
  , mkBoardFromPieces
  , rowsAsPieces
  , rowsAsStrings
  , colsAsPieces
  , next
  , prev
  , adjacent
  , get
  , getGridPieces
  , set
  , setN
  , setDeadPoints
  , isEmpty
  , stripOfPlay
  , inBounds
  , pointIsEmpty
  , pointIsNonEmpty
  , pointIsIsolatedInLine
  , pointHasRealNeighbor
  , validateCoordinate
  , validatePoint
  , farthestNeighbor
  , surroundingRange
  , getLetter
  , stripIsDisconnectedInLine
  , playableEnclosingStripsOfBlankPoints
  -- , groupedStrips
)
where

import Data.List
import qualified Data.Maybe as Maybe
import Data.Map (Map)
import qualified Data.Map as Map
import Data.Maybe (fromJust, isJust)

-- import qualified Data.ByteString.Char8 as BS

import Control.Monad.Except (MonadError(..))

import BoardGame.Common.Domain.PlayPiece (PlayPiece, PlayPiece(PlayPiece))
import qualified BoardGame.Common.Domain.PlayPiece as PlayPiece
import Bolour.Grid.GridValue (GridValue(GridValue))
import BoardGame.Common.Domain.GridPiece (GridPiece)
import qualified BoardGame.Common.Domain.GridPiece as GridPiece
import qualified Bolour.Grid.GridValue as GridValue
import BoardGame.Common.Domain.Piece (Piece, Piece(Piece))
import qualified BoardGame.Common.Domain.Piece as Piece
import Bolour.Grid.Point (Coordinate, Axis(..), Point, Point(Point))
import qualified Bolour.Grid.Point as Point
import qualified Bolour.Grid.Point as Axis
import Bolour.Grid.SparseGrid (SparseGrid)
import qualified Bolour.Grid.SparseGrid as SparseGrid
import BoardGame.Server.Domain.GameError (GameError(..))
import qualified Bolour.Util.MiscUtil as Util
import BoardGame.Server.Domain.Strip (Strip, Strip(Strip))
import qualified BoardGame.Server.Domain.Strip as Strip

{--
   A Board uses a SparseGrid to represent the contents of the board.
   Within a sparse grid, an empty slot is represented
   by Maybe.Nothing. But Board exposes pieces that represent
   emptiness by their value being null: '\0'. Where necessary,
   this module translates between these two representations of
   emptiness.
--}

-- | The game board.
data Board = Board {
    dimension :: Int
  , grid :: SparseGrid Piece
}
  deriving (Show)

-- TODO. Check rectangular. Check parameters. See below.
mkBoardFromPieces :: [[Maybe Piece]] -> Int -> Board
mkBoardFromPieces cells =
  let cellMaker row col = cells !! row !! col
  in mkBoard' cellMaker

-- TODO. Ditto.
mkBoard :: (Int -> Int -> Piece) -> Int -> Board
mkBoard pieceMaker =
  let cellMaker row col = Piece.toMaybe $ pieceMaker row col
  in mkBoard' cellMaker

mkEmptyBoard :: Int -> Board
mkEmptyBoard dimension =
  let grid = SparseGrid.mkEmptyGrid dimension dimension
  in Board dimension grid

mkBoard' :: (Int -> Int -> Maybe Piece) -> Int -> Board
mkBoard' cellMaker dimension =
  let grid = SparseGrid.mkGrid cellMaker dimension dimension
  in Board dimension grid

rowsAsPieces :: Board -> [[Piece]]
rowsAsPieces Board {grid} =
  let lineMapper row = (Piece.fromMaybe . fst) <$> row
  in lineMapper <$> SparseGrid.rows grid

colsAsPieces :: Board -> [[Piece]]
colsAsPieces Board {grid} =
  let lineMapper row = (Piece.fromMaybe . fst) <$> row
  in lineMapper <$> SparseGrid.cols grid

next :: Board -> Point -> Axis -> Maybe Piece
next Board {grid} point axis = do
  (maybePiece, _) <- SparseGrid.next grid point axis
  maybePiece

prev :: Board -> Point -> Axis -> Maybe Piece
prev Board {grid} point axis = do
  (maybePiece, _) <- SparseGrid.prev grid point axis
  maybePiece

adjacent :: Board -> Point -> Axis -> Int -> Maybe Piece
adjacent Board {grid} point axis direction = do
  (maybePiece, _) <- SparseGrid.adjacent grid point axis direction
  maybePiece

-- | Nothing if out of bounds, noPiece if empty but in bounds.
get :: Board -> Point -> Maybe Piece
get board @ Board { grid } point =
  if not (inBounds board point) then Nothing
  else
    let maybeVal = SparseGrid.get grid point
    in Just $ Piece.fromMaybe maybeVal

-- | Assume point is valid.
getLetter :: Board -> Point -> Char
getLetter board point =
  Piece.value $ Maybe.fromJust $ get board point

getGridPieces :: Board -> [GridPiece]
getGridPieces Board {grid} =
  let locatedPieces = SparseGrid.getJusts grid
      toGridPiece (piece, point) = GridValue piece point
  in toGridPiece <$> locatedPieces

set :: Board -> Point -> Piece -> Board
set Board { dimension, grid } point piece =
  let maybePiece = Piece.toMaybe piece
      grid' = SparseGrid.set grid point maybePiece
  in Board dimension grid'

setN :: Board -> [GridPiece] -> Board
setN board @ Board {dimension, grid} gridPoints =
  let toLocatedPoint GridValue {value = piece, point} =
        (Piece.toMaybe piece, point)
      locatedPoints = toLocatedPoint <$> gridPoints
      grid' = SparseGrid.setN grid locatedPoints
  in Board dimension grid'

setDeadPoints :: Board -> [Point] -> Board
setDeadPoints board points =
  let deadGridPiece point = GridValue Piece.deadPiece point
      deadGridPieces = deadGridPiece <$> points
  in setN board deadGridPieces

-- TODO. Implement SparseGrid.isEmpty and use it.
isEmpty :: Board -> Bool
isEmpty Board { grid } =
  let cellList = concat $ SparseGrid.rows grid
  in all (Maybe.isNothing . fst) cellList

pointIsEmpty :: Board -> Point -> Bool
pointIsEmpty Board {grid} point =
  Maybe.isNothing $ SparseGrid.get grid point

pointIsNonEmpty :: Board -> Point -> Bool
pointIsNonEmpty board point = not $ pointIsEmpty board point

inBounds :: Board -> Point -> Bool
inBounds Board {grid} = SparseGrid.inBounds grid

validateCoordinate :: MonadError GameError m =>
  Board -> Axis -> Coordinate -> m Coordinate

validateCoordinate (board @ Board { dimension }) axis coordinate =
  if coordinate >= 0 && coordinate < dimension then return coordinate
  else throwError $ PositionOutOfBoundsError axis (0, dimension) coordinate

validatePoint :: MonadError GameError m =>
  Board -> Point -> m Point

validatePoint board (point @ Point { row, col }) = do
  _ <- validateCoordinate board Y row
  _ <- validateCoordinate board X col
  return point

rowsAsStrings :: Board -> [String]
rowsAsStrings board = ((\Piece {value} -> value) <$>) <$> rowsAsPieces board

pointIsIsolatedInLine :: Board -> Point -> Axis -> Bool
pointIsIsolatedInLine Board {grid} = SparseGrid.isolatedInLine grid

pointHasRealNeighbor :: Board -> Point -> Axis -> Bool
pointHasRealNeighbor board point axis =
  let maybeNext = next board point axis
      maybePrev = prev board point axis
  in (isJust maybeNext && Piece.isReal (fromJust maybeNext)) ||
       (isJust maybePrev && Piece.isReal (fromJust maybePrev))

farthestNeighbor :: Board -> Point -> Axis -> Int -> Point
farthestNeighbor Board {grid} = SparseGrid.farthestNeighbor grid

stripOfPlay :: Board -> [PlayPiece] -> Maybe Strip
stripOfPlay board [] = Nothing
stripOfPlay board [playPiece] = stripOfPlay1 board playPiece
stripOfPlay board (pp:pps) = stripOfPlayN board (pp:pps)

stripOfPlay1 :: Board -> PlayPiece -> Maybe Strip
stripOfPlay1 board PlayPiece {point} =
  let Point {row, col} = point
      -- Arbitrarily choose the row of the single move play.
      line = rowsAsPieces board !! row
      lineAsString = Piece.piecesToString line
  in Just $ Strip.lineStrip Axis.X row lineAsString col 1

stripOfPlayN :: Board -> [PlayPiece] -> Maybe Strip
stripOfPlayN board playPieces =
  let rows = rowsAsPieces board
      cols = colsAsPieces board
      points = (\PlayPiece {point} -> point) <$> playPieces
      Point {row = hdRow, col = hdCol} = head points
      maybeAxis = Point.axisOfLine points
  in
    let mkStrip axis =
          let (lineNumber, line, begin) =
                case axis of
                  Axis.X -> (hdRow, rows !! hdRow, hdCol)
                  Axis.Y -> (hdCol, cols !! hdCol, hdRow)
              lineAsString = Piece.piecesToString line
           in Strip.lineStrip axis lineNumber lineAsString begin (length points)
    in mkStrip <$> maybeAxis

surroundingRange :: Board -> Point -> Axis -> [Point]
surroundingRange Board {grid} = SparseGrid.surroundingRange grid

-- | Check that a strip has no neighbors on either side - is disconnected
--   from the rest of its line. If it is has neighbors, it is not playable
--   since a matching word will run into the neighbors. However, a containing
--   strip will be playable and so we can forget about this strip.
stripIsDisconnectedInLine :: Board -> Strip -> Bool
stripIsDisconnectedInLine board (strip @ Strip {axis, begin, end, content})
  | (null content) = False
  | otherwise =
      let f = Strip.stripPoint strip 0
          l = Strip.stripPoint strip (end - begin)
          -- limit = dimension
          maybePrevPiece = prev board f axis
          maybeNextPiece = next board l axis
          isSeparator maybePiece =
            case maybePiece of
              Nothing -> True
              Just piece -> Piece.isEmpty piece
      in isSeparator maybePrevPiece && isSeparator maybeNextPiece

computeAllLiveStrips :: Board -> Axis -> [Strip]
computeAllLiveStrips board axis =
  let lines = case axis of
                Axis.X -> rowsAsPieces board
                Axis.Y -> colsAsPieces board
  in Strip.allLiveStrips axis (Piece.piecesToString <$> lines)

enclosingStripsOfBlankPoints :: Board -> Axis -> Map.Map Point [Strip]
enclosingStripsOfBlankPoints board axis =
  let liveStrips = computeAllLiveStrips board axis
      stripsEnclosingBlanks = filter Strip.hasBlanks liveStrips
  in Util.inverseMultiValuedMapping Strip.blankPoints stripsEnclosingBlanks

-- playableEnclosingStripsOfBlankPoints :: Axis -> Int -> Map.Map Point [Strip]
-- playableEnclosingStripsOfBlankPoints axis trayCapacity =
playableEnclosingStripsOfBlankPoints :: Board -> Axis -> Int -> Map.Map Point [Strip]
playableEnclosingStripsOfBlankPoints board axis trayCapacity =
  let enclosing = enclosingStripsOfBlankPoints board axis
      playable strip @ Strip {blanks, content} =
        blanks <= trayCapacity &&
          stripIsDisconnectedInLine board strip &&
          length content > 1 -- Can't play to a single blank strip - would have no anchor.
  in
    filter playable <$> enclosing

