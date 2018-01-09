--
-- Copyright 2017 Azad Bolour
-- Licensed under GNU Affero General Public License v3.0 -
--   https://github.com/azadbolour/boardgame/blob/master/LICENSE.md
--

module BoardGame.Util.WordUtil (
    LetterCombo
  , DictWord
  , WordIndex
  , ByteCount
  , BlankCount
  , mkLetterCombo
  , mergeLetterCombos
  -- , lookupWordIndex
  , computeCombos
  , computeCombosGroupedByLength
  ) where

-- import Data.ByteString.Char8
-- import qualified Data.ByteString.Char8 as BS
import Data.Map (Map)
import Data.List (sort)
import qualified Data.Map as Map
import qualified Data.Maybe as Maybe

import qualified Bolour.Util.MiscUtil as MiscUtil

-- | Combinations of letters (with repetition) sorted in a byte string.
type LetterCombo = String

-- | A dictionary word.
type DictWord = String

-- | Index of words.
--   Key is a combination of letters.
--   Value is permutations of the letters in the key that are actual words.
type WordIndex = Map LetterCombo [DictWord]

type ByteCount = Int
type BlankCount = Int

-- | Make a permutation of some letters, create the corresponding combination of those letters.
--   In our representation just sort the letters.
mkLetterCombo :: String -> LetterCombo
mkLetterCombo permutation = sort permutation

-- | Merge two combinations of letters.
mergeLetterCombos :: LetterCombo -> LetterCombo -> LetterCombo
mergeLetterCombos combo1 combo2 = sort $ combo1 ++ combo2

-- -- | Look up the words that are permutations of a given combination of letters.
-- lookupWordIndex :: LetterCombo -> WordIndex -> [DictWord]
-- lookupWordIndex letters wordIndex = Maybe.fromMaybe [] (Map.lookup letters wordIndex)

-- TODO. Eliminate duplicates for maximum performance.

-- | Compute all combinations of a set of letters and group them by length.
computeCombosGroupedByLength :: String -> Map ByteCount [LetterCombo]
computeCombosGroupedByLength bytes =
  let combos = computeCombos bytes
  in MiscUtil.mapFromValueList length combos

computeCombos :: String -> [LetterCombo]
computeCombos bytes = sort <$> computeCombosUnsorted bytes

computeCombosUnsorted :: String -> [String]
computeCombosUnsorted bytes
  | null bytes = [""]
  | otherwise =
      let h = head bytes
          t = tail bytes
          tailCombos = computeCombosUnsorted t
          combosWithHead = (:) h <$> tailCombos
      in tailCombos ++ combosWithHead


