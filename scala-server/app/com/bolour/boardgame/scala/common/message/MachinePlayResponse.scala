/*
 * Copyright 2017 Azad Bolour
 * Licensed under GNU Affero General Public License v3.0 -
 *    https://github.com/azadbolour/boardgame/blob/master/LICENSE.md
 */
package com.bolour.boardgame.scala.common.message

import com.bolour.boardgame.scala.common.domain.{GameMiniState, PlayPiece}

case class MachinePlayResponse(
  gameMiniState: GameMiniState,
  playedPieces: List[PlayPiece]
)
