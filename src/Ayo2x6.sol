// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;
import {Ayo} from "./Ayo.sol";
import {Ayo2x6Engine} from "./Ayo2x6Engine.sol";

/// @title Library for handling Ayo 2x6 board.
library Ayo2x6 {
    error ILLeGalMoVe();
    error cANnOtCOnstRuCtNeWBoaRd();

    uint256 private constant Ayo2x6BoardNewBoard = 0x410410412492492490000000000000000000000000C0;

    function newBoard() internal pure returns(uint256) {
        return Ayo2x6BoardNewBoard;
    }

    function applyMove(
        uint256 board, 
        uint256 move, 
        uint8 turn
    ) internal pure returns(uint256) {
        if(!isLegalMove(board, move, turn)){
            revert ILLeGalMoVe();
        }
        if(Ayo.generateMoves(board) == 0x0){
            return Ayo.flipTurnBit(board);
        }
        return Ayo.applyMove(board, move);
    }

    function constructNewBoard(uint256 board) internal pure returns(uint256) {
        uint256 p0PitsCaptured = Ayo.getP0PitsCaptured(board);
        uint256 p1PitsCaptured = Ayo.getP1PitsCaptured(board);
        // total pits should be equal to 12
        if((p0PitsCaptured + p1PitsCaptured) != 0x0C){
            revert cANnOtCOnstRuCtNeWBoaRd();
        }

        board &= 0xFFFFFFF;
        board |= getPitsCapturedMask(p0PitsCaptured);
        board = Ayo.resetTurnBit(board);
        return board;
    }

    function getPitsCapturedMask(uint256 p0PitsCaptured) internal pure returns(uint256) {
        if(p0PitsCaptured ==  0x0) { return 0x2492492492492492490000000000000000000000000C0; }
        if(p0PitsCaptured == 0x01) { return 0x492492492492492490000000000000000000000000C0;  }
        if(p0PitsCaptured == 0x02) { return 0x412492492492492490000000000000000000000000C0;  }
        if(p0PitsCaptured == 0x03) { return 0x410492492492492490000000000000000000000000C0;  }
        if(p0PitsCaptured == 0x04) { return 0x410412492492492490000000000000000000000000C0;  }
        if(p0PitsCaptured == 0x05) { return 0x410410492492492490000000000000000000000000C0;  }
        if(p0PitsCaptured == 0x07) { return 0x410410410492492490000000000000000000000000C0;  }
        if(p0PitsCaptured == 0x08) { return 0x410410410412492490000000000000000000000000C0;  }
        if(p0PitsCaptured == 0x09) { return 0x410410410410492490000000000000000000000000C0;  }
        if(p0PitsCaptured == 0x0A) { return 0x410410410410412490000000000000000000000000C0;  }
        if(p0PitsCaptured == 0x0B) { return 0x410410410410410490000000000000000000000000C0;  }
        if(p0PitsCaptured == 0x0C) { return 0x410410410410410410000000000000000000000000C0;  }
        return newBoard();
    }

    function isLegalMove(
        uint256 board, 
        uint256 move, 
        uint8 turn
    ) internal pure returns(bool ret) {
        bool expectedTurn = Ayo.getPlayerTurn(board);
        bool isValidMove = Ayo.isValidMove(board, move);
        uint256 pitOwner = Ayo.getPitOwner(move, board);
        assembly {
            ret := and(eq(expectedTurn, turn), isValidMove)
            ret := and(ret, eq(pitOwner, turn))
        }
    }

    function getPlayerTurn(uint256 board) internal pure returns(uint8 turn) {
        bool _turn = Ayo.getPlayerTurn(board);
        assembly{
            turn := _turn
        }
    }
}