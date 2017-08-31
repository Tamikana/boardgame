--
-- Copyright 2017 Azad Bolour
-- Licensed under GNU Affero General Public License v3.0 -
--   https://github.com/azadbolour/boardgame/blob/master/LICENSE.md
--
{-# LANGUAGE NamedFieldPuns #-}
{-# LANGUAGE DisambiguateRecordFields #-}
{-# LANGUAGE RecordWildCards #-}

module BoardGame.Server.Domain.IndexedStripMatcher (
    wordFitsContent
  , findFittingWord
  , matchFittingCombos
  , findOptimalMatch
  , computePlayableStrips
  ) where

import Data.Map (Map)
import qualified Data.Map as Map
import qualified Data.ByteString.Char8 as BS
import Data.ByteString.Char8 (ByteString)

import qualified BoardGame.Common.Domain.Piece as Piece
import BoardGame.Util.WordUtil (DictWord, LetterCombo, BlankCount, ByteCount)
import qualified BoardGame.Util.WordUtil as WordUtil
import BoardGame.Server.Domain.Strip (Strip, Strip(Strip), GroupedStrips)
import qualified BoardGame.Server.Domain.Strip as Strip
import BoardGame.Server.Domain.IndexedLanguageDictionary (IndexedLanguageDictionary, IndexedLanguageDictionary(IndexedLanguageDictionary))
import qualified BoardGame.Server.Domain.IndexedLanguageDictionary as IndexedLanguageDictionary
import Bolour.Util.MiscUtil as MiscUtil

blank = Piece.noPieceValue

-- | We know that the word and the strip have the same length.
--   So just check that the word matches the non-blank positions of the strip.
--   TODO. Inner loop. Should be made as efficient as possible.
wordFitsContent :: ByteString -> DictWord -> Bool
wordFitsContent stripContent word
  | BS.null stripContent && BS.null word = True
  | BS.null stripContent || BS.null word = False -- TODO. This case should not be necessary. Assert equal length.
  | otherwise =
     let stripHead = BS.head stripContent
         stripTail = BS.tail stripContent
         wordHead = BS.head word
         wordTail = BS.tail word
     in (stripHead == blank || stripHead == wordHead) && wordFitsContent stripTail wordTail
     -- TODO. Does the compiler optimize this to tail-recursive? Otherwise use explicit if-then-else.

-- | Find a match (if any) for a given strip.
--   Any match would do since our optimality measure is the total length
--   which is the length of the given strip. The combinations to try
--   are all of the right length to cover the strip's blanks.
findFittingWord ::
     IndexedLanguageDictionary  -- ^ the word dictionary to use
  -> BlankCount
  -> Strip                      -- ^ the strip
  -> [LetterCombo]              -- ^ combinations of letters to try on the strip's blanks
  -> Maybe (Strip, DictWord)    -- ^ longest word found if any

findFittingWord dictionary numBlanks strip [] = Nothing
findFittingWord dictionary numBlanks (strip @ Strip {letters, content}) (combo : combos) =
  let completeWordCombo = WordUtil.mergeLetterCombos letters combo
      words = IndexedLanguageDictionary.getWordPermutations dictionary completeWordCombo
      fittingWords = filter (wordFitsContent content) words
   in case fittingWords of
      [] -> findFittingWord dictionary numBlanks strip combos
      first : rest -> Just (strip, first)

matchFittingCombos ::
     IndexedLanguageDictionary
  -> BlankCount
  -> [Strip]
  -> [LetterCombo]
  -> Maybe (Strip, DictWord)

matchFittingCombos dictionary numBlanks [] combos = Nothing
matchFittingCombos dictionary numBlanks (strip : strips) combos =
  let maybeMatch = findFittingWord dictionary numBlanks strip combos
  in case maybeMatch of
     Nothing -> matchFittingCombos dictionary numBlanks strips combos
     Just match -> maybeMatch

-- | The fitting combos appears in descending order.
--   Each combo has exactly the same number of letters as needed to complete the corresponding strips.
--   TODO. Recurse on the list.
findOptimalMatchForFittingCombos ::
     IndexedLanguageDictionary
  -> [(BlankCount, ([Strip], [LetterCombo]))]
  -> Maybe (Strip, DictWord)

findOptimalMatchForFittingCombos dictionary [] = Nothing
findOptimalMatchForFittingCombos dictionary ((count, (strips, combos)) : tail) =
  let maybeMatch = matchFittingCombos dictionary count strips combos
  in case maybeMatch of
     Nothing -> findOptimalMatchForFittingCombos dictionary tail
     Just match -> maybeMatch

-- | Find a best match (if any) for strips of a given length.
findOptimalMatchForStripsByLength ::
     IndexedLanguageDictionary
  -> Map BlankCount [Strip]         -- ^ strips of a given length grouped by number of blanks
  -> Map ByteCount [LetterCombo]    -- ^ combinations of letters grouped by count
  -> Maybe (Strip, DictWord)

findOptimalMatchForStripsByLength dictionary stripsByBlanks combosByLength =
  -- Create a descending list of all: [(blanks, ([Strip], [combos]))] for strips of a given length.
  -- The strips have the given number of blanks.
  -- And the number of letters in each combo is also the number of blanks.
  -- So the combos can be used to fill the strips exactly.
  let matchedStripsAndCombos = Map.toDescList $ MiscUtil.zipMaps stripsByBlanks combosByLength
  in if null matchedStripsAndCombos then Nothing
     else findOptimalMatchForFittingCombos dictionary matchedStripsAndCombos

-- | Find a best match (if any) for strips of at most a given length.
--   Recursive on the length limit.
--   Recursion allows us to break out as soon as we find a match at the limit.
--   Recursive matches will all be shorter and therefore inferior.
findOptimalMatchForStripsOfLimitedLength ::
     IndexedLanguageDictionary
  -> ByteCount
  -> GroupedStrips
  -> Map ByteCount [LetterCombo]
  -> Maybe (Strip, DictWord)

findOptimalMatchForStripsOfLimitedLength dictionary limit groupedStrips combosByLength
  | limit <= 1 = Nothing
  | limit == 2 =
     do
       stripsByBlanks <- Map.lookup 2 groupedStrips
       findOptimalMatchForStripsByLength dictionary stripsByBlanks combosByLength
  | otherwise =
       let foundAtLimit =
             do
                stripsByBlanks <- Map.lookup limit groupedStrips
                findOptimalMatchForStripsByLength dictionary stripsByBlanks combosByLength
       in case foundAtLimit of
            Nothing -> findOptimalMatchForStripsOfLimitedLength dictionary (limit - 1) groupedStrips combosByLength
            Just found -> return found

findOptimalMatch ::
     IndexedLanguageDictionary -- ^ the dictionary of available words to match
  -> [String]   -- ^ the rows of the grid containing letters or blank (Piece.noPieceValue)
  -> String     -- ^ available characters that can be played
  -> Maybe (Strip, DictWord)

findOptimalMatch dictionary rows trayContent =
  let dimension = length rows
      trayLength = length trayContent
      playableStrips = computePlayableStrips rows trayLength
      trayBytes = BS.pack trayContent
      playableCombos = WordUtil.computeCombosGroupedByLength trayBytes
  in findOptimalMatchForStripsOfLimitedLength dictionary dimension playableStrips playableCombos

-- | Get the strips of a two-dimensional grid of characters that can potentially house a word.
--   A strip is playable iff it has at least 1 anchor letter,
--   and at most c blanks, where c is the capacity of the tray.
computePlayableStrips ::
     [String]     -- ^ rows or characters - upper-case letters or blank (Piece.noPieceValue)
  -> Int          -- ^ tray capacity - maximum number of blanks in a play strip
  -> Map ByteCount (Map BlankCount [Strip])

computePlayableStrips rows trayCapacity =
  let dimension = length rows
      allStrips = Strip.allStripsByLengthByBlanks rows dimension
      blanksFilter blanks strips = blanks > 0 && blanks <= trayCapacity
      filterPlayableBlanks stripsByBlanks = blanksFilter `Map.filterWithKey` stripsByBlanks
      playableStrips = filterPlayableBlanks <$> allStrips
      hasAnchor strip @ Strip { letters } = BS.length letters > 0
      filterStripsForAnchor = filter hasAnchor -- :: [Strip] -> [Strip]
      filterStripsByBlankForAnchor = (filterStripsForAnchor <$>) -- :: Map BlankCount [Strip] -> Map BlankCount [Strip]
      playableStrips' = filterStripsByBlankForAnchor <$> playableStrips
  in playableStrips'


