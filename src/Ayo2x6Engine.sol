// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;
import {Ayo} from "./Ayo.sol";
import {Utils} from "./vendor/Utils.sol";

/// @title A 2x6 ayo game engine using minimax algorithm with αβ pruning.
library Ayo2x6Engine {

    /// @notice Search for best move to play.
    /// @return Best move.
    function searchMoves(uint256 board, uint256 depth) internal pure returns(uint256){
        int256 bestScore = -0x12C0;
        int256 alpha = type(int256).min;
        int256 beta = type(int256).max;
        int256 currentScore;
        uint256 bestMove;
        uint256 moves = Ayo.generateMoves(board);
        for(; moves != 0x0; moves >>= 0x06){
            uint256 move = moves & 0x3F;
            uint256 _board = Ayo.applyMove(board, move);
            bool maximizing = !Ayo.getPlayerTurn(board);
            currentScore = evaluateBoard(_board) + minimax(
                _board,
                alpha, 
                beta,
                depth - 0x01,
                maximizing
            );
            if (currentScore > bestScore) {
                bestScore = currentScore;
                bestMove = move;
            }
            alpha = Utils.max(alpha, currentScore);
        }
        return bestMove;
    }

    /// @notice Basic minimax strategy with pruning.
    function minimax(
        uint256 board,
        int256 alpha,
        int256 beta, 
        uint256 depth,
        bool maximizing
    ) internal pure returns(int256) {
        if (depth == 0x0 || isGameOver(board)) {
            return evaluateBoard(board);
        }

        if (maximizing) {
            int256 bestScore = -0x12C0;
            uint256 moves = Ayo.generateMoves(board);
            for (; moves != 0x0; moves >>= 0x06) {
                int256 score = minimax(
                    Ayo.applyMove(board, moves & 0x3F), 
                    alpha, 
                    beta, 
                    depth - 0x01, 
                    false
                );
                bestScore = Utils.max(bestScore, score);
                alpha = Utils.max(alpha, bestScore);
                // α cut-off
                if (beta <= alpha) {
                    break;
                }
            }
            return bestScore;
        } else {
            int256 bestScore = 0x12C0;
            uint256 moves = Ayo.generateMoves(board);
            for (; moves != 0x0; moves >>= 0x06) {
                int256 score = minimax(
                    Ayo.applyMove(board, moves & 0x3F), 
                    alpha, 
                    beta, 
                    depth - 0x01, 
                    true
                );
                bestScore = Utils.min(bestScore, score);
                beta = Utils.min(beta, bestScore);
                // β cut-off
                if (beta <= alpha) {
                    break;
                }
            }
            return bestScore;
        }
    }

    /// @dev Board evaluation strategy:
    ///          Seeds in pit(SP)   -> no. of seeds * 60
    ///          Captured seeds(CP) -> no. of captured seeds * 100
    ///     evaluation = P0(SP + CP) - P1(SP + CP)
    /// @param board Board to evaluate.
    /// @return eval result.
    function evaluateBoard(uint256 board) internal pure returns(int256){
        (uint256 p0PitMoves, uint256 p1PitMoves) = !Ayo.getPlayerTurn(board)
            ? (Ayo.generateMoves(board), Ayo.generateMoves(Ayo.flipTurnBit(board)))
            : (Ayo.generateMoves(Ayo.flipTurnBit(board)), Ayo.generateMoves(board));
        uint256 p0PitSeeds;
        uint256 p1PitSeeds;
        for(; p0PitMoves != 0x0; p0PitMoves >>= 0x06){
            p0PitSeeds += Ayo.getPitSeeds(p0PitMoves & 0x3F, board);
        }
        for(; p1PitMoves != 0x0; p1PitMoves >>= 0x06){
            p1PitSeeds += Ayo.getPitSeeds(p1PitMoves & 0x3F, board);
        }
        uint256 p0Points = (p0PitSeeds * 0x3C) + (Ayo.getP0PitsCaptured(board) * 0x64);
        uint256 p1P0ints = (p1PitSeeds * 0x3C) + (Ayo.getP1PitsCaptured(board) * 0x64);
        return int256(p0Points) - int256(p1P0ints);
    }

    /// @dev Game is over if board becomes empty.
    /// @param board Game board to check.
    /// @return bool. Whether game is over.
    function isGameOver(uint256 board) internal pure returns(bool){
        return Ayo.isEmptyBoard(board);
    }
}