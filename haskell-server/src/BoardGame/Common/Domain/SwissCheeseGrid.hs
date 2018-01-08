--
-- Copyright 2017 Azad Bolour
-- Licensed under GNU Affero General Public License v3.0 -
--   https://github.com/azadbolour/boardgame/blob/master/LICENSE.md
--

{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE NamedFieldPuns #-}
{-# LANGUAGE DisambiguateRecordFields #-}
{-# LANGUAGE StandaloneDeriving #-}
{-# LANGUAGE DeriveFunctor #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE ScopedTypeVariables #-}

module BoardGame.Common.Domain.SwissCheeseGrid (
      SwissCheeseGrid
    , mkGrid
    , mkEmptyGrid
    , height
    , width
    , cells
    , get
    , getJusts
    , set
    , setN
    , next
    , prev
    , adjacent
    , isolatedInLine
    , inBounds
  ) where

import Data.List
import Data.Maybe (isJust, fromJust, isNothing)
import BoardGame.Common.Domain.Point (Point, Point(Point), Axis, Coordinate, Height, Width)
import qualified BoardGame.Common.Domain.Point as Axis
import qualified BoardGame.Common.Domain.Point as Point
import qualified BoardGame.Common.Domain.Grid as Grid
import BoardGame.Common.Domain.Grid (Grid, Grid(Grid))

type LocatedValue val = (Maybe val, Point)

data SwissCheeseGrid val = SwissCheeseGrid {
    height :: Height
  , width :: Width
  , cells :: [[LocatedValue val]]
  , get :: Point -> Maybe val
  , getJusts :: [(val, Point)]
  , set :: Point -> Maybe val -> SwissCheeseGrid val
  , setN :: [(Maybe val, Point)] -> SwissCheeseGrid val
  , next :: Point -> Axis -> Maybe val
  , prev :: Point -> Axis -> Maybe val
  , adjacent :: Point -> Axis -> Int -> Maybe val
  , isolatedInLine :: Point -> Axis -> Bool
  , inBounds :: Point -> Bool
}

instance (Show val) => Show (SwissCheeseGrid val)
  where show SwissCheeseGrid {cells} = show cells

mkGrid :: (Height -> Width -> Maybe val) -> Height -> Width -> SwissCheeseGrid val
mkGrid cellMaker height width =
  let pointedCellMaker row col = (cellMaker row col, Point row col)
      grid = Grid.mkGrid pointedCellMaker height width
  in mkInternal grid

mkEmptyGrid :: Height -> Width -> SwissCheeseGrid val
mkEmptyGrid = mkGrid (\height width -> Nothing)

-- TODO. Any way to add type signatures to functions below for clarity.
-- Compiler did not accept scoped types with type parameters.

mkInternal :: Grid (LocatedValue val) -> SwissCheeseGrid val
mkInternal grid @ Grid {height, width, cells} =
  SwissCheeseGrid height width cells get getJusts set setN next prev adjacent isolated inBounds
    where get point = do
            (maybeVal, _) <- Grid.get grid point
            maybeVal
          set point value =
            let grid' = Grid.set grid point (value, point)
            in mkInternal grid'
          next point axis = do
            (maybeVal, _) <- Grid.next grid point axis
            maybeVal
          prev point axis = do
            (maybeVal, _) <- Grid.prev grid point axis
            maybeVal
          adjacent point axis direction =
            let calcAdj = if direction == 1 then next else prev
            in calcAdj point axis
          inBounds = Grid.inBounds grid
          setN locatedPoints =
            let addPoint located @ (value, point) = (located, point)
                locatedPoints' = addPoint <$> locatedPoints
                grid' = Grid.setN grid locatedPoints'
            in mkInternal grid'
          getJusts =
            let justs = filter (\(may, point) -> isJust may) (Grid.concatGrid grid)
                mapper (may, point) = (fromJust may, point)
            in mapper <$> justs
          isolated point axis =
             isNothing (next point axis) && isNothing (prev point axis)
