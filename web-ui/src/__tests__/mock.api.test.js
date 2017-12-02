/*
 * Copyright 2017 Azad Bolour
 * Licensed under GNU Affero General Public License v3.0 -
 *   https://github.com/azadbolour/boardgame/blob/master/LICENSE.md
 */

'use strict';

import GameParams from "../domain/GameParams";
import {mkPiece} from "../domain/Piece";
import {mkPoint} from "../domain/Point";
import * as Piece from "../domain/Piece";
// import TestUtil from "./TestHelper"
import {mkMovePlayPiece, mkCommittedPlayPiece} from "../domain/PlayPiece";
import GameService from "../service/GameService"

// TODO. Clean up promise tests.
// Returning a promise from a test is sufficient.
// JEST will wait until the promise is completed.

// Note. If done is not called within a timeout, the test fails.
// That will happen in case of exceptions and reject.

let gameParams = GameParams.defaultParams();
let uPieces = [mkPiece('B', "1"), mkPiece('E', "2"), mkPiece('T', "3")];
let mPieces = [mkPiece('S', "4"), mkPiece('T', "5"), mkPiece('Z', "6")];
let center = parseInt(gameParams.dimension/2);
// Make a row play.
let userPlayPieces = [
  mkMovePlayPiece(uPieces[0], mkPoint(center, center - 1)),
  mkMovePlayPiece(uPieces[1], mkPoint(center, center)),
  mkMovePlayPiece(uPieces[2], mkPoint(center, center + 1))
];

test('start a new game', done => {

  let game = undefined;
  let gameService = new GameService(gameParams);
  gameService.start([], [], []).then(response => {
    game = response.json;
    expect(game.tray.pieces.length).toBe(gameParams.trayCapacity);
    expect(game.board.dimension).toBe(gameParams.dimension);
    done();
  }).catch(error => {
    console.log(JSON.stringify(error));
    throw error;
  });
});

test('commit play', done => {
  // let gameParams = GameParams.defaultParams();
  let game = undefined;
  let gameService = new GameService(gameParams);
  // let leftPiece = mkPiece('B', 'idLeft');
  // let rightPiece = mkPiece('T', 'idRight');
  // let initUserTray = [leftPiece, rightPiece];

  gameService.start([], uPieces, mPieces).then(response => {
    game = response.json;
    // TODO. expect good game
    // let $game = TestUtil.addInitialPlayToGame(game);
    // let playPieces = $game.getUserMovePlayPieces();
    // expect(playPieces.length).toBe(2);

    return gameService.commitUserPlay(game.gameId, userPlayPieces);
  }).then(myResponse => {
    let refillPieces = myResponse.json;
    expect(refillPieces.length).toBe(3);
    done();
  }).catch(error => {
    console.log(JSON.stringify(error));
    throw error;
  });
});

test('machine play', done => {
  // let gameParams = GameParams.defaultParams();
  let game = undefined;
  let gameService = new GameService(gameParams);
  // let leftPiece = mkPiece('B', 'idLeft');
  // let rightPiece = mkPiece('T', 'idRight');
  // let initUserTray = [leftPiece, rightPiece];

  gameService.start([], uPieces, mPieces).then(response => {
    game = response.json;
    // let $game = TestUtil.addInitialPlayToGame(game);
    // let playPieces = $game.getUserMovePlayPieces();
    return gameService.commitUserPlay(game.gameId, userPlayPieces);
  }).then(response => {
    let refillPieces = response.json;
    expect(refillPieces.length).toBe(3);
    return gameService.getMachinePlay(game.gameId);
  }).
  then(response => {
    let play = response.json;
    let moves = play.moves();
    expect(moves.length).toBeGreaterThan(0);
    done();
  }).
  catch(error => {
    console.log(JSON.stringify(error));
    throw error;
  });
});









