/*
 * Copyright 2017 Azad Bolour
 * Licensed under GNU Affero General Public License v3.0 -
 *   https://github.com/azadbolour/boardgame/blob/master/LICENSE.md
 */

/**
 * @module MockGameImpl.
 */

import * as Piece from '../domain/Piece';

const pieceMoves = true;

// TODO. Change name to MockApiImpl.

// TODO. Take account of initialGrid and initial machine pieces.

class MockGameImpl {
  constructor(gameId, gameParams, initGridPieces, initUserTray, initMachineTray) {
    // TODO. Reflect initial conditions on game. Check server-side code for logic.
    this.gameParams = gameParams;
    this.nextPieceId = 0;
    this.dimension = gameParams.height;
    // this.machineTray = this.mkMachineTray();
    this.machinePieces = this.getPieces(gameParams.trayCapacity);
    this.moves = [];
    // this.numPiecesInPlay = this.machineTray.pieces.length; // TODO. Use method.
    this.gameId = gameId;
    // TODO. Only do this if initGridPieces is not provided.
    const mid = Math.floor(gameParams.height / 2);
    const midPiece = this.getPiece();
    const pos = {row: mid, col: mid};
    const pos1 = {row: mid + 1, col: mid - 1};
    const piece1 = this.getPiece();
    const midGridPiece = {
      point: pos,
      value: midPiece
    };
    const otherGridPiece = {
      point: pos1,
      value: piece1
    };

    const additionalTrayPieces = this.getPieces(gameParams.trayCapacity - initUserTray.length);;
    const trayPieces = initUserTray.concat(additionalTrayPieces);

    this.gameDto = {
      gameId: gameId,
      height: gameParams.height,
      width: gameParams.width,
      trayCapacity: gameParams.trayCapacity,
      gridPieces: [midGridPiece, otherGridPiece],
      trayPieces: trayPieces
    };
  }

  // Begin Api.

  swap(piece) {
    return this.getPiece();
  }

  commitPlay(playPieces) {
    let it = this;
    let movedPlayPieces = playPieces.filter(p => p.moved);
    this.reflectMovesOnGame(movedPlayPieces);
    let usedUp = movedPlayPieces.length;
    movedPlayPieces.forEach(p =>
      it.removePieceById(it.gameDto.trayPieces, p.piece));
    let refills = this.getPieces(usedUp);
    refills.forEach(p =>
      it.gameDto.trayPieces.push(p));
    return refills;
  }

  /**
   * For now find the first position that has two empty positions below
   * and move the first two pieces from the tray to it.
   *
   * TODO. Add horizontal check as well.
   */
  getMachinePlay() {
    let it = this;

    // Find an anchor to start from.
    let start = this.filledPositions().find(pos => it.twoBelowEmpty(pos, this.dimension));
    // console.log(`start: ${JSON.stringify(start)}`);
    if (start === undefined) return [];
    let startPiece = this.getPieceAtGridPoint(start);
    let startPlayPiece = this.mkPlayPiece(startPiece, start, !pieceMoves);

    // console.log(`startPlayPiece: ${JSON.stringify(startPlayPiece)}`);

    // Create moves from machine tray to 2 slots below the anchor.
    if (this.machinePieces.length < 2) return [];
    const [piece0, piece1] = this.machinePieces;
    // let piece0 = this.machinePieces[0];
    // let piece1 = this.machinePieces[1];
    const below = {row: start.row + 1, col: start.col};
    const belowBelow = {row: start.row + 2, col: start.col};
    const belowPlayPiece = this.mkPlayPiece(piece0, below, pieceMoves);
    const belowBelowPlayPiece = this.mkPlayPiece(piece1, belowBelow, pieceMoves);

    // Update and restock the machine tray.
    this.removePieceById(this.machinePieces, piece0);
    this.removePieceById(this.machinePieces, piece1);
    const refills = this.getPieces(2);
    refills.forEach(p => it.machinePieces.push(p));

    // Reflect the moves onto the board.
    const playPieces = [startPlayPiece, belowPlayPiece, belowBelowPlayPiece];
    const movedPlayPieces = playPieces.filter(p => p.moved);
    this.reflectMovesOnGame(movedPlayPieces);

    // Return entire sequence of play pieces to be returned, moved or not.
    return playPieces;
  }

  // Future API member.
  selectFirstPlayer() {
    let player = Math.random() < 0.5 ? 'player' : 'machine'; // TODO. Common constants.
    return {
      player: player
    };
  }

  // End Api.
  
  // Begin auxiliary functions. Use in unit tests but not part of the api.
  
  filledPositions() {
    // console.log(`${JSON.stringify(this.gameDto.gridPieces)}`);
    return this.gameDto.gridPieces.map(gridPiece => gridPiece.point);
  }

  posFilled(pos) {
    return this.filledPositions().some (p => p.row === pos.row && p.col === pos.col);
  }

  posEmpty(pos) {
    return !this.posFilled(pos);
  }

  getPieces(numPieces) {
    let pieces = new Array;
    for (let i = 0; i < numPieces; i++)
      pieces.push(this.getPiece());
    return pieces;
  }

  getPiece() {
    this.nextPieceId += 1;
    const piece = {
      value: Piece.randomLetter(),
      id: String(this.nextPieceId)
    }
    this.numPiecesInPlay += 1;
    return piece;
  }
  
  // End auxiliary functions.

  // TODO. Private functions. Move these out of the class.

  // Assumes gridPoint has a piece.
  getPieceAtGridPoint(point) {
    const gridPiece = this.gameDto.gridPieces.find(gp => {
      let gpPoint = gp.point;
      return point.row === gpPoint.row && point.col === gpPoint.col;
    });
    return (gridPiece !== undefined) ? gridPiece.value : undefined; // TODO. Avoid verbosity.
  }

  removePieceById(pieces, piece) {
    const index = pieces.findIndex (function(p) {
      return (p.id === piece.id);
    });
    pieces.splice(index, 1);
  }

  mkPlayPiece(piece, point, moved) {
    return {
      point,
      piece,
      moved
    };
  }

  reflectMovesOnGame(movedPlayPieces) {
    let it = this;
    // console.log(`moved play pieces: ${JSON.stringify(movedPlayPieces)}`);
    movedPlayPieces.forEach(playPiece =>
      // this.gameDto.gridPieces.push(playPiece.gridPiece));
      this.gameDto.gridPieces.push({piece: playPiece.piece, point: playPiece.point})
    );
  }

  twoBelowEmpty(pos, dimension) {
    // console.log(`pos: ${JSON.stringify(pos)}, dimension: ${JSON.stringify(dimension)}`);
    if (pos.row + 2 >= dimension)
      return false;
    return (this.posEmpty({row: pos.row + 1, col: pos.col}) && this.posEmpty({row: pos.row + 2, col: pos.col}));
  }
}

export default MockGameImpl;