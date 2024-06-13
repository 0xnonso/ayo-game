// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {Ayo} from "../src/Ayo.sol";
import {Ayo2x6} from "../src/Ayo2x6.sol";
import {Ayo2x6Engine} from "../src/Ayo2x6Engine.sol";
import {AyoBoard} from "../src/AyoBoard.sol";
import {PlayAyo2x6} from "../src/PlayAyo2x6.sol";
import {Ayo2x6Tournament} from "../src/Ayo2x6Tournament.sol";

contract AyoTest is Test {
    PlayAyo2x6 ayo;
    Ayo2x6Tournament tourney;
    address player0 = address(0xdead);
    address player1 = address(0xb0b);

    function setUp() public {
        ayo = new PlayAyo2x6(player0, player1, 1);
        tourney = new Ayo2x6Tournament();
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
            // console2.log(move);
            move = Ayo.getPitIndex(move, board);

            // prank first player
            vm.startPrank(player0);
            ayo.playGame(move, 0, true);
            vm.stopPrank();

            (board, ,) = ayo.getGameData();
            move = Ayo2x6Engine.searchMoves(board, 3);
            // console2.log(move);
            if(move == 0) break;
            move = Ayo.getPitIndex(move, board);
            
            // prank second player
            vm.startPrank(player1);
            ayo.playGame(move, 0, true);
            vm.stopPrank();
        }
    }

    function testTournament() public {
        // prank first player
        vm.deal(player0, 1 ether);
        vm.startPrank(player0);
        tourney.joinGame();
        tourney.mintBoard{value: 3_000_000_000_000_000}();
        tourney.mintPits{value: tourney.getPitPrice(6, 5)}(6);
        vm.stopPrank();

        // prank second player
        vm.deal(player1, 1 ether);
        vm.startPrank(player1);
        tourney.joinGame();
        tourney.mintBoard{value: 3_000_000_000_000_000}();
        vm.stopPrank();

        address t = tourney.createGame(player0, player1);

        vm.startPrank(player0);
        PlayAyo2x6(t).forfeitGame();
        vm.stopPrank();

        tourney.endGame(t);

        vm.startPrank(player0);
        tourney.burnPits(6);
        vm.stopPrank();
    }
}