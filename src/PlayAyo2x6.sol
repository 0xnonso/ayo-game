// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;
import {Ayo} from "./Ayo.sol";
import {Ayo2x6} from "./Ayo2x6.sol";
import {AyoBoard} from "./AyoBoard.sol";
import {Ayo2x6Engine} from "./Ayo2x6Engine.sol";
import {ERC721} from "./vendor/ERC721.sol";
import {Ownable} from "./vendor/Ownable.sol";

contract PlayAyo2x6 is ERC721, Ownable {

    uint256 private constant TIME_OUT = 420 seconds; // 7 minutes
    address private constant GAME_ENGINE = address(0x01);
    address private constant ADDRESS_ZERO = address(0x0);
    
    uint256 private immutable MAX_GAME_ROUNDS;

    uint256 internal gameBoard;
    uint256 internal totalSupply;
    uint256 internal lastMoveTimestamp;

    string private baseURI;

    mapping(uint256 => address) internal playerAddress;
    mapping(uint256 => Move) internal moves;

    struct Move {
        uint256 board;
        uint256 move;
    }

    event GameCreated(address p0, address p1);
    event GameJoined(uint8 playerID);
    event GameForfieted(bool player1);

    constructor(address player0, address player1, uint256 gameRounds) {
        _initializeOwner(msg.sender);
        uint256 newBoard = Ayo2x6.newBoard();

        playerAddress[0x0]  = player0;
        playerAddress[0x01] = player1;

        if(player1 == GAME_ENGINE){
            newBoard = newBoard | 0x01;
            _joinGame(newBoard, true);
        }
        MAX_GAME_ROUNDS = gameRounds;
        lastMoveTimestamp = block.timestamp;
        gameBoard = newBoard;
        emit GameCreated(player0, player1);
    }

    function playGame(uint256 move, uint256 depth, bool mintMove) public {
        uint256 board = gameBoard;
        require(!gameEnded(board), "game has ended");

        move =  Ayo.getPitIndexNormalised(move, board);
        if(!canPlayGame(board)){
            revert();
        }
        lastMoveTimestamp = uint64(block.timestamp);
        uint8 pTurn = Ayo2x6.getPlayerTurn(board);

        require(playerAddress[pTurn] == msg.sender, "not turn");

        board = Ayo2x6.applyMove(board, move, pTurn);

        uint256 _totalSupply = totalSupply;
        moves[_totalSupply] = Move({ board: board, move : move });
        if(mintMove){
            _safeMint(msg.sender, _totalSupply);
            totalSupply++;
        }

        // engine is always the second player (player 1)
        if(isEngineOpps(board)){
            uint256 engineMove = Ayo2x6Engine.searchMoves(board, depth);
            board = Ayo2x6.applyMove(board, engineMove, 0x01);
            _totalSupply = totalSupply;
            moves[_totalSupply] = Move({ board: board, move : move });
            if(mintMove){
                _safeMint(msg.sender, _totalSupply);
                totalSupply++;
            }
        }

        if(Ayo.isEmptyBoard(board)){
            // if game rounds == MAX_GAME_ROUNDS, set winner
            if(Ayo.getGameRounds(board) == MAX_GAME_ROUNDS){
                uint256 p0Captured = Ayo.getP0PitsCaptured(board); 
                uint256 p1Captured = Ayo.getP1PitsCaptured(board); 
                board = Ayo.setWinner(
                    board, 
                    p1Captured > p0Captured, 
                    p0Captured == p1Captured
                );
            } else {
                // else construct new board
                board = Ayo2x6.constructNewBoard(board);
            }
        }
        gameBoard = board;
    }

    function forfeitGame() external {
        // get player turn
        uint256 board = gameBoard;
        require(!gameEnded(board), "game has ended");
        uint8 pTurn = Ayo2x6.getPlayerTurn(board);
        bool _pTurn;
        if(timeout()){
            assembly { _pTurn := pTurn }
        } else {
            // player that forfeits always lose.
            require(playerAddress[pTurn] == msg.sender);
            assembly { _pTurn := not(pTurn) }
        }
        gameBoard = Ayo.setWinner(board, _pTurn, false);
        emit GameForfieted(_pTurn);
    }

    function joinGame(bool player1) external {
        uint8 playerID;
        assembly {
            playerID := player1
        }
        address toJoin = playerAddress[playerID];
        if(toJoin == ADDRESS_ZERO){
            playerAddress[playerID] = msg.sender;
            toJoin = msg.sender;
        }
        require(toJoin == msg.sender);
        gameBoard = _joinGame(gameBoard, player1);
        lastMoveTimestamp = block.timestamp;
        emit GameJoined(playerID);
    }

    function name() public pure override returns (string memory){
        return unicode"AyóAyó";
    }

    /// @dev Returns the token collection symbol.
    function symbol() public pure override returns (string memory){
        return "ayo";
    }

    function tokenURI(uint256 _tokenId) public view override returns (string memory){
        return bytes(baseURI).length == 0x0
            ? _tokenURI(_tokenId)
            : string(abi.encodePacked(baseURI, _tokenId));
    }

    function _tokenURI(uint256 _tokenId) public view returns (string memory) {
        return AyoBoard.getMetadata(moves[_tokenId].board, moves[_tokenId].move);
    }

    function setBaseURI(string memory _baseURI) external onlyOwner {
        baseURI = _baseURI;
    }

    function getGameData() public view returns(uint256, address, address) {
        return(gameBoard, playerAddress[0], playerAddress[1]);
    }

    function gameEnded(uint256 board) internal pure returns(bool) {
        return Ayo.gameEnded(board);
    }

    function canPlayGame(uint256 board) internal pure returns(bool) {
        // whether both players have joined.
        return Ayo.getJoinStatus(board) == 0x03;
    }

    function timeout() internal view returns(bool){
        return block.timestamp > lastMoveTimestamp + TIME_OUT;
    }

    function isEngineOpps(uint256 board) internal pure returns(bool isOpps) {
        assembly {
            isOpps := and(board, 0x01)
        }
    }

    function _joinGame(uint256 board, bool player1) internal pure returns(uint256){
        return Ayo.joinGame(board, player1); 
    }
}