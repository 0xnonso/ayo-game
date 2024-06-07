// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

/// @title Generic Library for handling Ayo 2xN board. where: 1 < N ≤ 19.
///
///                                                                                                                  
///           ┌──────────────────────────────────────────────────────────────────────────────────────┐ 
///           │┌────────┐  .─────.    .─────.    .─────.    .─────.    .─────.    .─────.  ┌────────┐│ 
///           ││  ****  │ ╱  * *  ╲  ╱       ╲  ╱       ╲  ╱       ╲  ╱  * *  ╲  ╱       ╲ │  ****  ││ 
///           ││  ****  │(  *****  )(    *    )(   * *   )(         )(  *****  )(    *    )│  ****  ││ 
///           ││        │ `. *** ,'  `.     ,'  `.     ,'  `.     ,'  `. *** ,'  `.     ,' │  ****  ││ 
///           ││        │   `───'      `───'      `───'      `───'      `───'      `───'   │        ││
///           ││        │  .─────.    .─────.    .─────.    .─────.    .─────.    .─────.  │        ││ 
///           ││        │ ╱       ╲  ╱       ╲  ╱       ╲  ╱       ╲  ╱       ╲  ╱       ╲ │        ││ 
///           ││        │(   * *   )(    *    )(         )(         )(         )(   * *   )│        ││ 
///           ││        │ `.     ,'  `.     ,'  `.     ,'  `.     ,'  `.     ,'  `.     ,' │        ││ 
///           │└────────┘   `───'      `───'      `───'      `───'      `───'      `───'   └────────┘│ 
///           └──────────────────────────────────────────────────────────────────────────────────────┘       
///
///
///
/// @dev Each Ayo pit is represented with 6 bits.
///         - The first bit represents the pit color. 0 for dark brown pit(P0), 1 for grey pit(P1).
///         - The remaining 5 bits represents the number of seeds in the pit. This implies
///             that the maximum number of seeds that can ever be in a pit is 2 ** 5 - 1.
///
///     The whole board is represented with 38 indices each holding 6 bits which is 228 bits.
///
///         1 ->  37 36 35 34 33 32 31 30 29 28 27 26 25 24 23 22 21 20 19
///         0 ->  00 01 02 03 04 05 06 07 08 09 10 11 12 13 14 15 16 17 18
///
///     A brand new 2x7 Ayo board is represented as:   00 00 00 00 00 00 00 00 00 00 00 00 20 20 20 20 20 20 20
///                                                    00 00 00 00 00 00 00 00 00 00 00 00 04 04 04 04 04 04 04
///
///      The Ayo game board is packed together with its game data and stored in a single word(uint256).
///                    - Board -> 228 bits
///                    - Game data:
///                        * P0 Pits Captured -> 6 bits. Stores total pits captured by P0.
///                        * P1 Pits Captured -> 6 bits. Stores total pits captured by P1.
///                        * Turn -> 1 bits. Represents player turn, 0 for P0 and 1 for P1.
///                        * Game Rounds Played -> 5 bits. Stores the number of game rounds played in a board.
///                        * Board Width -> 5 bits. Stores the game's board dimension.
///                                                 i.e a 2x9 ayo board has board width of 9.
///                        * Winner -> 2 bits. Stores game winner information. First bit represents whether a game winner is set.
///                                             00 -> No winner!
///                                             10 -> P0 won!
///                                             11 -> P1 won!
///                                             01 -> Draw!
///                        * Game Joined -> 2 bits. Stores whether a player has joined a game.
///                                                 00 -> No player has joined!
///                                                 10 -> Only P0 joined!
///                                                 01 -> Only P1 joined!
///                                                 11 -> Both players joined.
///
///     ┌─────┐                                                                                                                           
///     │ PIT │                                                                                                                           
///     └─────┘                                                                                                                           
///        ▲                                                                                                                               
///        │                                                                                                                               
///   ┌────┴──┬─────────────────────────┬───────┬────────────────────────────────────────────────────────────────────────────────────────┐ 
///   │   6   │                        ││   6   │                        │       │       │       │       │       │       │       │       │ 
///   ├───────┘                        │└───────┘                        │◀──6──▶│◀──6──▶│◀──1──▶│◀──5──▶│◀──5──▶│◀──2──▶│◀──2──▶│◀──1──▶│ 
///   │◀─────────────114─────────────▶ │ ◀─────────────114─────────────▶ │       │       │       │       │       │       │       │       │ 
///   └───────────────┬─────────────────────────────────┬───────────────────┬─────────┬──────┬───────┬───────┬───────┬───────┬───────┬───┘ 
///                   │                                 │                   │         │      │       │       │       │       │       │     
///                   │                                 │                   │         │      │       │       │       │       │       │     
///                   ▼                                 ▼                   ▼         ▼      ▼       ▼       ▼       ▼       ▼       ▼     
///              ┌────────┐                        ┌────────┐          ┌────────┐┌────────┐┌────┐┌───────┐┌─────┐┌──────┐┌──────┐ ┌───────┐
///              │P0 PITS │                        │P1 PITS │          │P0 PITS ││P1 PITS ││TURN││ GAME  ││BOARD││WINNER││ GAME │ │ EMPTY │
///              └────────┘                        └────────┘          │CAPTURED││CAPTURED│└────┘│ROUNDS ││WIDTH│└──────┘│JOINED│ └───────┘
///                                                                    └────────┘└────────┘      │PLAYED │└─────┘        └──────┘          
///                                                                                              └───────┘
///
library Ayo {
    /// @notice Sow seeds from `move` index on `board` until it hits an empty pit.
    ///         Seeds are sown in an anti-clockwise direction.
    /// @dev If `move` is out of board range the original board is returned. However sometimes this 
    ///         may not be the case if the board initially contained uncaptured pits.
    /// @param board Board where seeds from `move` are sown on.
    /// @param move Index where desired pit to sow is located.
    /// @return New Board with updated pits after sowing.
    function applyMove(uint256 board, uint256 move) internal pure returns(uint256) {
        // If it is the first move don't capture pits.
        if (!isNewBoard(board)){
            board = capturePits(board);
            if (isEmptyBoard(board)) {
                return board;
            }
        }

        bool playerTurn = getPlayerTurn(board);
        uint256 boardWidth = getBoardWidth(board);

        assembly {
            let indexMul := mul(move, 0x06)
            let shiftrMask := shr(indexMul, 0x7C00000000000000000000000000000000000000000000000000000000000000)
            // set numSeeds to seeds in the current pit.
            let numSeeds := shr(0xFA, shl(indexMul, and(shiftrMask, board)))
            if eq(numSeeds, 0x0){
                mstore(0x0, board)
                return(0x0, 0x20)
            }
            // clear starting pit
            board := and(board, not(shiftrMask))
            let range := add(boardWidth, boardWidth)
            let lastPitIndex := sub(numSeeds, 0x01)
            let lBound := sub(0x13, boardWidth)
            let playerWithLastCapture := 0x0
            let i := 0x0
            // for seeds in pit sow seed to all other pits till you hit an empty pit.
            for {} lt(i, numSeeds) {i := add(i, 0x01)} {
                let currentIndex := add(lBound, mod(add(move, i), range))
                indexMul := mul(currentIndex, 0x06)

                shiftrMask := not(shr(indexMul, 0x7C00000000000000000000000000000000000000000000000000000000000000))

                // increment pit.
                board := add(
                    board, shr(add(indexMul, 0x05), 0x8000000000000000000000000000000000000000000000000000000000000000)
                )
                let ayoPit := shr(
                    0xFA, 
                    shl(indexMul, and(shr(indexMul, 0xFC00000000000000000000000000000000000000000000000000000000000000), board))
                )
                let ayoPitSeed := and(ayoPit, 0x1F)
                let ayoPitID := shr(0x05, ayoPit)

                // if pit seeds eq 4 set pit to zero, update pit captured.
                if eq(ayoPitSeed, 0x04) {
                    // set pit to 0
                    board := and(board, shiftrMask)
                    // if last index set ayopitId to turn.
                    if eq(i, lastPitIndex) {
                        ayoPitID := playerTurn
                        ayoPitSeed := 0x0
                    }
                    // update player pit captured.
                    board := add(board, shr(mul(0x06, ayoPitID), 0x400000)) 
                    // update player with last capture.
                    playerWithLastCapture := ayoPitID
                } 
                // final pit.
                if eq(i, lastPitIndex) {
                    if gt(ayoPitSeed, 0x01) {
                        numSeeds := add(numSeeds, ayoPitSeed)
                        lastPitIndex := sub(numSeeds, 0x01)
                        // set pit seeds to 0
                        board := and(board, shiftrMask)
                    }
                }

                let totalPitsCaptured := add(and(shr(0x16, board), 0x3F), and(shr(0x10, board), 0x3F))
                if eq(totalPitsCaptured, sub(range, 0x01)) {
                    // set all pits to zero.
                    board := and(board, 0x820820820820820820820820820820820820820820820820820820820FFFFFFF)
                    // update player pit score.
                    board := add(board, shr(mul(0x06, playerWithLastCapture), 0x400000))
                    // increment game rounds
                    board := add(board, 0x400)
                    break
                }
            }
            // flip board turn bit.
            board := or(
                and(board, 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF7FFF), 
                xor(and(board, 0x8000), 0x8000)
            )
        }
        return board;
    }                   

    /// @notice Generate all possible moves for player turn in game board.
    /// @param board Game board to generate moves from.
    /// @return moves All possible moves bit packed together.
    function generateMoves(uint256 board) internal pure returns(uint256 moves){
        bool pTurn = getPlayerTurn(board);
        uint256 boardWidth = getBoardWidth(board);
        (int256 startIndex, int256 endIndex, int256 i) = pTurn 
            ? (int256(0x12 + boardWidth), int256(0x13 - boardWidth), -0x01)
            : (int256(0x13 - boardWidth), int256(0x12 + boardWidth), int256(0x01));

        uint256 movesIndex;
        for(; startIndex != endIndex + i; startIndex += i) {
            int256 indexMul = startIndex * 0x06;
            bool ownsPit;
            uint256 pitSeed;
            assembly {
                let ayoPit := shr(
                    0xFA, 
                    shl(indexMul, and(shr(indexMul, 0xFC00000000000000000000000000000000000000000000000000000000000000), board))
                )
                let ayoPitSeed := and(ayoPit, 0x1F)
                let ayoPitID := shr(0x05, ayoPit)
                ownsPit := eq(ayoPitID, pTurn)
                pitSeed := ayoPitSeed
            }

            if(!ownsPit){ break; }
            if (pitSeed != 0x0) {
                moves |= uint256(startIndex & 0x3F) << (movesIndex * 0x06);
                movesIndex++;
            }
        }
    }

    /// @notice Captures all uncaptured pits. A pit can be captured if number of seeds in a pit is 4.
    ///        The captured pit is given to the owner of the pit.
    /// @param board Board to capture pits from.
    /// @return Updated board after pits capture.
    function capturePits(uint256 board) internal pure returns(uint256){
        // if board comes with only four seeds add the last remaining pit to previous player captured pits.
        bool playerWithLastCapture = !getPlayerTurn(board);
        uint256 boardWidth = getBoardWidth(board);
        assembly {
            let range := add(boardWidth, boardWidth)
            let maxPitsCaptured := sub(range, 0x01)
            let startIndex := sub(0x13, boardWidth)
            let i := 0x0
            for {} lt(i, range) {i := add(i, 0x01)}{
                let currentIndex := add(startIndex, mod(i, range))
                let indexMul := mul(currentIndex, 0x06)

                // get the current pit seeds
                let ayoPit := shr(
                    0xFA, 
                    shl(indexMul, and(shr(indexMul, 0xFC00000000000000000000000000000000000000000000000000000000000000), board))
                )
                let ayoPitSeed := and(ayoPit, 0x1F)
                let ayoPitID := shr(0x05, ayoPit)

                // if pit seeds in eq to 4, get the player id
                if eq(ayoPitSeed, 0x04) {
                    // set pit to 0
                    board := and(board, not(shr(indexMul, 0x7C00000000000000000000000000000000000000000000000000000000000000)))
                    // update player pitscore
                    board := add(board, shr(mul(0x06, ayoPitID), 0x400000))
                    // update player with last capture.
                    playerWithLastCapture := ayoPitID
                }

                let totalPitsCaptured := add(and(shr(0x16, board), 0x3F), and(shr(0x10, board), 0x3F))
                if eq(totalPitsCaptured, maxPitsCaptured) {
                    // set all pits to zero
                    board := and(board, 0x820820820820820820820820820820820820820820820820820820820FFFFFFF)
                    // update player pit score
                    board := add(board, shr(mul(0x06, playerWithLastCapture), 0x400000))
                    break
                }
            }
        }
        return board;
    }
    
    /// @notice Checks if a board is empty. A board is empty if all moves have been exhausted.
    /// @param board Board to check.
    /// @return isEmpty Whether the board is empty.
    function isEmptyBoard(uint256 board) internal pure returns(bool isEmpty){
        assembly {
            isEmpty := iszero(and(board, 0x7DF7DF7DF7DF7DF7DF7DF7DF7DF7DF7DF7DF7DF7DF7DF7DF7DF7DF7DF0000000))
        }
    }
    
    /// @notice Checks if `board` is a new ayo game board. A new board will contain 4 seeds in all pit.
    /// @dev Seeds represented in a new Ayo2x6 game board:  
    ///                         00 00 00 00 00 00 00 00 00 00 00 00 00 04 04 04 04 04 04
    ///                         00 00 00 00 00 00 00 00 00 00 00 00 00 04 04 04 04 04 04
    /// @param board Board to check.
    /// @return isNew Whether board is new board.
    function isNewBoard(uint256 board) internal pure returns(bool isNew){
        uint256 boardWidth = getBoardWidth(board);
        uint256 shiftl = (0x13 - boardWidth) * 0x06;
        assembly {
            let mask := shr(shiftl, shl(add(shiftl, shiftl), 0x1041041041041041041041041041041041041041041041041041041040000000))
            isNew := eq(
                mask, 
                and(board, 0x7DF7DF7DF7DF7DF7DF7DF7DF7DF7DF7DF7DF7DF7DF7DF7DF7DF7DF7DF0000000)
            )
        }
    }

    /// @return boardWidth Game board width.
    function getBoardWidth(uint256 board) internal pure returns(uint256 boardWidth){
        assembly {
            boardWidth := and(shr(0x05, board), 0x1F)
        }
    }

    /// @notice Get the number of seeds in a specific pit index.
    /// @dev `index` to get seeds from is the raw index. i.e In a 2x6 ayo board the first pit index will be 13,
    ///         The second pit index will be 14 ....
    /// @param index Index to get seeds from.
    /// @param board Game Board.
    /// @return seed Number of seeds in a pit.
    function getPitSeeds(uint256 index, uint256 board) internal pure returns(uint256 seed){
        assembly{
            let indexMul := mul(index, 0x06)
            seed := and(
                shr(
                    0xFA, 
                    shl(indexMul, and(shr(indexMul, 0xFC00000000000000000000000000000000000000000000000000000000000000), board))
                ), 
                0x1F
            )
        }
    }

    /// @notice Get the number of seeds in a specific pit index.
    /// @dev Adjusted `index` is used here instead of raw index. ie first pit in a 2x6 ayo board
    ///     is 0 not 13.
    /// @param index Index to get seeds from.
    /// @param board Game Board.
    /// @return seed Number of seeds in a pit.
    function getPitSeedsNormalised(uint256 index, uint256 board) internal pure returns(uint256 seed){
        uint256 boardWidth = getBoardWidth(board);
        assembly{
            seed := and(shr(sub(0xFA, mul(0x06, add(sub(0x13, boardWidth), index))), board), 0x1F)
        }
    }

    /// @return owner Owner of pit.
    function getPitOwner(uint256 index, uint256 board) internal pure returns(uint256 owner){
        assembly{
            owner := and(shr(sub(0xFF, mul(0x06, index)), board), 0x01)
        }
    }

    /// @notice Get whose turn it is to sow seed on the board.
    /// @return turn Player turn
    function getPlayerTurn(uint256 board) internal pure returns(bool turn){
        assembly{
            turn := and(shr(0xF, board), 0x01)
        }
    }

    /// @dev `move` is only valid if it is within the board range.
    /// @return isValid Whether move is valid
    function isValidMove(uint256 board, uint256 move) internal pure returns(bool isValid){
        uint256 boardWidth = getBoardWidth(board);
        assembly {
            isValid := and(gt(move, sub(0x12, boardWidth)), lt(move, add(0x13, boardWidth)))
        }
    }

    /// @return captured Number of P0 pits captured.
    function getP0PitsCaptured(uint256 board) internal pure returns(uint256 captured){
        assembly {
            captured := and(shr(0x16, board), 0x3F)
        }
    }

    /// @return captured Number of P1 pits captured.
    function getP1PitsCaptured(uint256 board) internal pure returns(uint256 captured){
        assembly {
            captured := and(shr(0x10, board), 0x3F)
        }
    }

    /// @return num Number of game rounds played.
    function getGameRounds(uint256 board) internal pure returns(uint256 num) {
        assembly {
            num := and(shr(0xA, board), 0x1F)
        }
    }

    /// @notice Reset turn bit.
    /// @dev The new turn is set based on the number of game rounds played.
    ///      Turn is set to game_rounds % 2.
    /// @param board Board to reset turn.
    /// @return newBoard Game Board with the reset turn.
    function resetTurnBit(uint256 board) internal pure returns(uint256 newBoard){
        uint256 gameRound = getGameRounds(board);
        assembly {
            newBoard := or(
                and(board, 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF7FFF), 
                xor(and(board, 0x8000), shl(0xF, mod(gameRound, 0x02)))
            )
        }
    }

    /// @dev Flips turn bit. If initial turn is 0, it gets flipped to 1.
    function flipTurnBit(uint256 board) internal pure returns(uint256 newBoard){
        assembly {
            newBoard := or(
                and(board, 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF7FFF), 
                xor(and(board, 0x8000), 0x8000)
            )
        }
    }

    /// @dev Convert raw pit index to adjusted pit index.
    ///         i.e For 2x6 board: index 13 -> 0
    ///                            index 14 -> 1
    ///      Also note that result can be subject to underflow of index.
    /// @param index Raw index to convert.
    /// @param board Game Board.
    /// @return pitIndex Return adjusted pit index.
    function getPitIndex(uint256 index, uint256 board) internal pure returns(uint256 pitIndex){
        uint256 boardWidth = getBoardWidth(board);
        assembly {
            pitIndex := sub(index, sub(0x13, boardWidth))
        }
    }

    /// @dev Convert normalised/adjusted pit index to raw pit index.
    ///         i.e For 2x6 board: index 0 -> 13
    ///                            index 1 -> 14
    ///      Also note that result can be subject to overflow of index.
    /// @param index Raw index to convert.
    /// @param board Game Board.
    /// @return pitIndex Return adjusted pit index. 
    function getPitIndexNormalised(uint256 index, uint256 board) internal pure returns(uint256 pitIndex){
        uint256 boardWidth = getBoardWidth(board);
        assembly {
            pitIndex := add(index, sub(0x13, boardWidth))
        }
    }

    /// @notice Set game winner status.
    /// @dev uint8(`player1`) is used to set winner. So if P0 is the winner. `player1` is 0 and vice versa.
    /// @param board Game Board.
    /// @param player1 Winner to set
    /// @param draw If game is a draw.
    /// @return Game Board
    function setWinner(uint256 board, bool player1, bool draw) internal pure returns(uint256) {
        // zero out winner slot.
        board &= 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFE7;
        uint256 winnerStatus;
        if(!draw){
            winnerStatus = 0x10;
        } else {
            board |= 0x8;
            return board;
        }
        assembly {
            board := or(or(board, winnerStatus), shl(0x04, player1))
        }
        return board;
    }

    /// @notice Join ayo game board.
    /// @param board Game Board
    /// @param player1 Player to join gome
    /// @return Game Board.
    function joinGame(uint256 board, bool player1) internal pure returns(uint256) {
        // flip join bits
        assembly {
            board := or(board, shl(add(player1, 0x01), 0x01))
        }
        return board;
    }

    /// @return ended Whether ayo game has ended.
    function gameEnded(uint256 board) internal pure returns(bool ended) {
        // winner set
        assembly {
            ended := and(shr(0x03, board), 0x03)
        }
    }

    /// @return status Game joined status.
    function getJoinStatus(uint256 board) internal pure returns(uint256 status) {
        // return both players joined or game rounds > 1
        assembly {
            status := and(shr(0x01, board), 0x03)
        }
    }

    /////////////////////////////////////////////////////////////////////////////
    ///                                 CUSTOM                                ///
    /////////////////////////////////////////////////////////////////////////////
    
    /// @notice Similar to `applyMove(...)`. Sow seeds from `move` index on `board`.
    /// @dev Adds support for more customizable ayo games with more than 2 players.
    ///      Board does not utilze stored game data here so game data storage is more flexible.
    ///      An exception is the total pits captured during the game that is stored in the first 
    ///      6 bits after the board bits [228...234] to enable the board handle pit capture efficiently.
    /// @param board Board where seeds from `move` are sown on.
    /// @param move Index where desired pit to sow is located.
    /// @param nPlayers Number of players participating in a game.
    /// @return New Board with updated pits after sowing.
    /// @return Score Board with pit captures. All scores are represented with 5 bits and bitpacked into the 
    ///         score board.
    function applyMoveCustom(
        uint256 board, 
        uint256 move,
        uint256 nPlayers
    ) internal pure returns(uint256, uint256) {
        uint256 boardWidth = getBoardWidth(board);
        // assert nplayers % 2 == 0
        // assert boardWidth % (nPlayers/2) == 0
        if(nPlayers % 0x02 != 0x0 && boardWidth % (nPlayers / 0x2) != 0x0){
            return(board, 0x0);
        }
        nPlayers = (2 * boardWidth) / nPlayers;
     
        uint256 scoreBoard;

        assembly {
            // uint256 playerTurn = getPitIndex(move, board) / nPlayers;
            mstore(0x80, div(sub(move, sub(0x13, boardWidth)), nPlayers))
            // let range := add(boardWidth, boardWidth)
            mstore(0xA0, add(boardWidth, boardWidth))
            // let playerWithLastCapture := 0x0
            mstore(0xC0, 0x0)

            let indexMul := mul(move, 0x06)
            let shiftrMask := shr(indexMul, 0x7C00000000000000000000000000000000000000000000000000000000000000)
            // set numSeeds to seeds in the current pit.
            let numSeeds := shr(0xFA, shl(indexMul, and(shiftrMask, board)))
            if eq(numSeeds, 0x0){
                mstore(0x0, board)
                return(0x0, 0x40)
            }
            // clear starting pit
            board := and(board, not(shiftrMask))
            
            let lastPitIndex := sub(numSeeds, 0x01)
            let lBound := sub(0x13, boardWidth)
            let i := 0x0
            // for seeds in pit sow seed to all other pits till you hit an empty pit.
            for {} lt(i, numSeeds) {i := add(i, 0x01)} {
                let currentIndex := add(lBound, mod(add(move, i), mload(0xA0)))
                indexMul := mul(currentIndex, 0x06)

                shiftrMask := not(shr(indexMul, 0x7C00000000000000000000000000000000000000000000000000000000000000))

                // increment pit.
                board := add(
                    board, shr(add(indexMul, 0x05), 0x8000000000000000000000000000000000000000000000000000000000000000)
                )
                
                let ayoPitSeed := and(
                    shr(
                        0xFA, 
                        shl(indexMul, and(shr(indexMul, 0xFC00000000000000000000000000000000000000000000000000000000000000), board))
                    ), 
                    0x1F
                )
                // let ayoPitID := shr(0x05, ayoPit)
                let ayoPitID := div(sub(currentIndex, sub(0x13, boardWidth)), nPlayers)
                
                // if pit seeds eq 4 set pit to zero, update pit captured.
                if eq(ayoPitSeed, 0x04) {
                    // set pit to 0
                    board := and(board, shiftrMask)
                    // if last index set ayopitId to turn.
                    if eq(i, lastPitIndex) {
                        ayoPitID := mload(0x80)
                        ayoPitSeed := 0x0
                    }
                    // update player pit captured.
                    // board := add(board, shr(mul(0x06, ayoPitID), 0x400000))
                    board := add(board, 0x400000)
                    scoreBoard := add(scoreBoard, shl(mul(0x05, ayoPitID), 0x01))
                    // update player with last capture.
                    // playerWithLastCapture := ayoPitID
                    mstore(0xC0, ayoPitID)
                } 
                // final pit.
                if eq(i, lastPitIndex) {
                    if gt(ayoPitSeed, 0x01) {
                        numSeeds := add(numSeeds, ayoPitSeed)
                        lastPitIndex := sub(numSeeds, 0x01)
                        // set pit seeds to 0
                        board := and(board, shiftrMask)
                    }
                }

                if eq(and(shr(0x16, board), 0x3F), sub(mload(0xA0), 0x01)) {
                    // set all pits to zero.
                    board := and(board, 0x820820820820820820820820820820820820820820820820820820820FFFFFFF)
                    // update player pit score.
                    board := add(board, 0x400000)
                    scoreBoard := add(scoreBoard, shl(mul(0x05, mload(0xC0)), 0x01))
                    break
                }
            }
        }
        return (board, scoreBoard);
    }

}