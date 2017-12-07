/*
 * Copyright 2017 Azad Bolour
 * Licensed under GNU Affero General Public License v3.0 -
 *   https://github.com/azadbolour/boardgame/blob/master/LICENSE.md
 */

/** @module BoardSquare */

import React from 'react';
const ItemTypes = require('./DragDropTypes').ItemTypes;
const DropTarget = require('react-dnd').DropTarget;
import SquareComponent from './SquareComponent';
import actions from '../event/GameActions';
import {mkPiece} from '../domain/Piece';
import {mkPoint} from '../domain/Point';
import {mkGridPiece} from '../domain/GridPiece';
import {stringify} from "../util/Logger";

const PropTypes = React.PropTypes;

/**
 * Color coding style for move destinations (drop targets of the the piece being dragged).
 * It style is absolute w.r.t. to its parent (the board square), and its dimensions
 * are the same as the board square so it covers the same area as the board square.
 */
function colorCodedLegalMoveStyle(pixels, colorCoding) {
  const pix = pixels + 'px';
  return {
    position: 'absolute',
    top: 0,
    left: 0,
    height: pix,
    width: pix,
    zIndex: 1,
    opacity: 0.5,
    backgroundColor: colorCoding
  };
}

/**
 * The style for indicating that a piece on the board has been moved
 * during the current play - is in the current play but not yet committed.
 */
function inPlayStyle() {
  const pix = '6px';
  return {
    position: 'absolute',
    top: 1,
    left: 1,
    height: pix,
    width: pix,
    zIndex: 1,
    color: 'white',
    backgroundColor: 'GoldenRod'
  };
}

function scoreStyle(scoreMultiplier, squarePixels) {
  const height = 10;
  const width = 15;
  let top = squarePixels - height;
  let left = squarePixels - width;
  return {
    position: 'absolute',
    top: top,
    left: left,
    height: height + 'px',
    width: width + 'px',
    zIndex: 1,
    color: 'white',
    backgroundColor: 'Blue',
    opacity: 0.5,
    fontSize: 10
  };
}

/**
 * Style for the square - it is relative to its siblings within its parent.
 */
function squareStyle(pixels) {
  let pix = pixels + 'px';
  return {
    position: 'relative',
    width: pix,
    height: pix
  };
}

let getMonitorPiece = function(monitor) {
  let pieceItem = monitor.getItem();
  return mkPiece(pieceItem.value, pieceItem.id);
};

const MIN_MOVEMENT = 15;

const vectorMagnitude = (x, y) => Math.sqrt(x ** 2 + y ** 2);
const isMinimallyMoved = ({ x, y }) => vectorMagnitude(x, y) > MIN_MOVEMENT;

/**
 * An object that tells the react DnD framework how to drop
 * a dragged item. This object is given as a parameter
 * to the DropTarget decorator (see export below).
 *
 * The props in the callback methods of this object are the props
 * of drop target component - the component that is a candidate
 * for a possible drop.
 *
 * In this case the props are the props of the board square that
 * is a possible destination of a drop of a piece.
 *
 * The monitor in the callback methods provides information about what
 * is being dragged. Its getItem method returns the item provided by
 * the drag source. In this case, the drag source is a Piece,
 * and as a drag source it has a corresponding pieceDragger whose
 * beginDrag method returns the "drag source" item, which the
 * monitor's "getItem" method returns.
 *
 * See the React documentation for the API of drop targets.
 */
const pieceDropper = {
  canDrop: function (props, monitor) {
    let piece = getMonitorPiece(monitor);
    let point = props.point;
    let legal = props.isLegalMove(piece, point);
    // A workaround to avoid react dnd glitch preventing drag.
    let minimallyMoved = isMinimallyMoved((monitor.getDifferenceFromInitialOffset()));
    return minimallyMoved && legal && props.enabled;
  },

  drop: function (props, monitor) {
    let piece = getMonitorPiece(monitor);
    let point = props.point;
    let move = mkGridPiece(piece, point);
    actions.move(move);
  }
};

/**
 * A function that tells the react dnd framework what drag and drop
 * properties to inject into objects that are subject to drag and drop
 * context - I guess the descendants of a component decorated
 * as a drag drop context. This is called a 'collect' function in
 * the react dnd jargon. It is given as a parameter to the drop target
 * decorator (see export below).
 *
 * @param connect - see React DND docs.
 * @param monitor DropTargetMonitor - see React DND docs.
 */
function injectedDropTargetProperties(connect, monitor) {
  return {
    connectDropTarget: connect.dropTarget(),
    isOver: monitor.isOver(),
    canDrop: monitor.canDrop()
  };
}

/**
 * Get the shade of the checker at the given position - light or dark square.
 */
function checkerShade(point) {
  return (point.row + point.col) % 2 === 0 ? 'light' : 'dark'; // TODO. Constants.
}

/**
 * A given square on the board.
 *
 * The parent component (Board), being wrapped in a drag-drop context,
 * passes drag-drop properties to its children. They include isOver,
 * and canDrop.
 *
 * Note that the position of the square is a plain javascript
 * object with row and col fields. React dnd needs plain objects to
 * act as dragged items. That is why we did not abstract
 * board position to its own class. There were issues with
 * class instances and react dnd.
 */
let BoardSquareComponent = React.createClass({
  propTypes: {
    /**
     * The position of the square on the board.
     */
    point: PropTypes.shape({
      row: PropTypes.number.isRequired,
      col: PropTypes.number.isRequired
    }).isRequired,

    /**
     * The number of pixels in each side of the square.
     */
    squarePixels: PropTypes.number.isRequired,

    /**
     * Does this square form part of the current play?
     * That is, has a piece been moved to this square during
     * the currently ongoing play, but the play has not
     * been committed yet?
     */
    inPlay: PropTypes.bool.isRequired,

    /**
     * Is the cursor over the current square?
     */
    isOver: PropTypes.bool.isRequired,

    /**
     * Is it legal to drop the current piece being dragged onto
     * this square?
     */
    isLegalMove: PropTypes.func.isRequired,

    canDrop: PropTypes.bool.isRequired,

    /**
     * Responds to user interactions.
     */
    enabled: PropTypes.bool.isRequired,

    // Note connectDropTarget is also injected.
  },

  render: function () {
    let connectDropTarget = this.props.connectDropTarget;
    let isOver = this.props.isOver;
    let canDrop = this.props.canDrop;
    let shade = checkerShade(this.props.point);
    let pixels = this.props.squarePixels;
    let inPlay = this.props.inPlay;

    let isLight = (shade === 'light'); // TODO. Constant.
    let backgroundColor = isLight ? 'CornSilk' : 'AquaMarine';
    let color = 'OrangeRed';
    let enabled = this.props.enabled;

    return connectDropTarget(
      <div style={squareStyle(pixels)}>

        <SquareComponent
          pixels={pixels}
          color={color}
          backgroundColor={backgroundColor}
          enabled={enabled}>
          {this.props.children}
        </SquareComponent>

        {isOver && !canDrop && <div style={colorCodedLegalMoveStyle(pixels, 'red')} />}
        {!isOver && canDrop && <div style={colorCodedLegalMoveStyle(pixels, 'yellow')} />}
        {isOver && canDrop && <div style={colorCodedLegalMoveStyle(pixels, 'green')} />}
        {inPlay && <div style={inPlayStyle()} />}
        {true && <div style={scoreStyle(null, pixels)} >3W</div>}

      </div>
    );
  }
});

/**
 * Decorator of the BoardSquare as a drop target.
 *
 * The item type says which type of item can be dropped on the
 * given component.
 *
 * The piece dropper is called back to find out if it is legal
 * to drop an item on the given component, and to trigger the
 * required action to be performed on a drop.
 *
 * The injected drop target properties is called back to get
 * an associative array of the properties to be injected into
 * the drop target - the board square in this case.
 */

export default DropTarget(ItemTypes.PIECE, pieceDropper, injectedDropTargetProperties)(BoardSquareComponent);

