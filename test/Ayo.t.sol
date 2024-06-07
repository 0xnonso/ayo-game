// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {Ayo} from "../src/Ayo.sol";
import {Ayo2x6} from "../src/Ayo2x6.sol";
import {Ayo2x6Engine} from "../src/Ayo2x6Engine.sol";
import {AyoBoard} from "../src/AyoBoard.sol";
import {PlayAyo2x6} from "../src/PlayAyo2x6.sol";

contract AyoTest is Test {
    PlayAyo2x6 ayo;
    address player0 = address(0xdead);
    address player1 = address(0xb0b);

    function setUp() public {
        ayo = new PlayAyo2x6(player0, player1, 1);
    }

    function testPlay() public {
        vm.startPrank(player0);
        ayo.joinGame(false);
        vm.stopPrank();
        vm.startPrank(player1);
        ayo.joinGame(true);
        vm.stopPrank();
        
        uint256 move = type(uint).max;
        uint256 board;
        for(uint256 i;move!=0; i++){
            (board, ,) = ayo.getGameData();
            move = Ayo2x6Engine.searchMoves(board, 3);
            console2.log(move);
            move = Ayo.getPitIndex(move, board);

            // prank first player
            vm.startPrank(player0);
            ayo.playGame(move, 0, true);
            vm.stopPrank();

            (board, ,) = ayo.getGameData();
            move = Ayo2x6Engine.searchMoves(board, 3);
            console2.log(move);
            if(move == 0) break;
            move = Ayo.getPitIndex(move, board);
            
            // prank second player
            vm.startPrank(player1);
            ayo.playGame(move, 0, true);
            vm.stopPrank();
        }
    }
}