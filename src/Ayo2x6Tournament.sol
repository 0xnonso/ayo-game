// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;
import {Ownable} from "./vendor/Ownable.sol";
import {Ayo, PlayAyo2x6} from "./PlayAyo2x6.sol";

contract Ayo2x6Tournament is Ownable {

    uint256 internal immutable BASE_PIT_COST;
    uint256 internal immutable DELTA;
    address internal immutable TOURNAMENT_FUND;

    uint256 internal totalPitsSupply = 0;
    uint256 internal totalBoardsSupply = 0;

    mapping(address => bool) internal isBoardMinted;
    mapping(address => bool) internal pending;
    mapping(address => bool) internal gameCreated;

    mapping(address => uint256) internal pitsSupply;
    mapping(address => uint256) internal pitsOwned;

    event NewTournamentGameCreated(address gameCreated);
    event JoinedTournamentEvent(address player);
    event TournamentGameEnded(address gameAddress);
    event PitsBurnt(address user, uint256 amount);
    event PitsMinted(address user, uint256 amount);

    constructor() {
        _initializeOwner(msg.sender);
        BASE_PIT_COST = 500_000_000_000_000;
        DELTA = 100_000_000_000_000;
        TOURNAMENT_FUND = address(this);
    }

    function createGame(address p0, address p1) external returns(address){
        require(pending[p0] && pending[p1], "player not registered");
        require(isBoardMinted[p0] && pitsOwned[p0] >= 6, "p0 not enough pits to play");
        require(isBoardMinted[p1] && pitsOwned[p1] >= 6, "p1 not enough pits to play");

        PlayAyo2x6 newGame = new PlayAyo2x6(p0, p1, 1);
        gameCreated[address(newGame)] = true;
        pending[p0] = false;
        pending[p1] = false;
        pitsOwned[p0] -= 6;
        pitsOwned[p1] -= 6;
        emit NewTournamentGameCreated(address(newGame));
        return address(newGame);
    }

    function joinGame() external {
        pending[msg.sender] = true;
        emit JoinedTournamentEvent(msg.sender);
    }

    function endGame(address gameAddress) external {
        require(gameCreated[gameAddress], "game doesn't exist");
        (uint256 board, address p0, address p1) = PlayAyo2x6(gameAddress).getGameData();
        bool gameEnded = Ayo.gameEnded(board);
        require(gameEnded, "tournament game has not ended");

        uint256 p0PitsCapt = Ayo.getP0PitsCaptured(board);
        uint256 p1PitsCapt = Ayo.getP1PitsCaptured(board);
        if(gameEnded && (p0PitsCapt + p1PitsCapt) != 12){
            (p0PitsCapt, p1PitsCapt) = Ayo.getWinnerStatus(board) == 2 
                ? (8, 4) : (4, 8);
        }
        pitsOwned[p0] += p0PitsCapt;
        pitsOwned[p1] += p1PitsCapt;
        gameCreated[gameAddress] = false;
        emit TournamentGameEnded(gameAddress);
    }

    function burnPits(uint256 amount) external payable {
        uint256 _pitsOwned = pitsOwned[msg.sender];
        uint256 _pitsSupply = pitsSupply[msg.sender];
        uint256 diff = _pitsOwned > _pitsSupply 
            ? _pitsOwned - _pitsSupply
            : 0;
        _pitsOwned -= amount;
        if(amount > diff) {
            _pitsSupply -= (amount - diff);
        } 
        require(_pitsSupply >= 6, "min pit supply exceeded");
        pitsOwned[msg.sender] = _pitsOwned; 
        pitsSupply[msg.sender] = _pitsSupply;

        amount *= BASE_PIT_COST; 
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "transfer failed");
        emit PitsBurnt(msg.sender, amount);
    }

    function mintPits(uint256 amount) external payable {
        if(isBoardMinted[msg.sender]){
            uint256 pitCost = getPitPrice(amount, pitsSupply[msg.sender] - 5);
            require(msg.value >= pitCost, "not enough funds");
            pitsOwned[msg.sender] += amount;
            pitsSupply[msg.sender] += amount;
            totalPitsSupply += amount;
            (bool success, ) = TOURNAMENT_FUND.call{value: pitCost}("");
            require(success, "transfer failed");
            emit PitsMinted(msg.sender, amount);
        } else {
            mintBoard();
        }
    }

    function mintBoard() public payable {
        require(!isBoardMinted[msg.sender]);
        isBoardMinted[msg.sender] = true;

        //calculate cost of 6 pits and mint;
        uint256 pitCost = BASE_PIT_COST * 6;
        require(msg.value >= pitCost, "not enough funds");

        pitsOwned[msg.sender] = 6;
        pitsSupply[msg.sender] = 6;
        totalBoardsSupply += 1;

        (bool success, ) = TOURNAMENT_FUND.call{value: pitCost}("");
        require(success, "transfer failed");
        emit PitsMinted(msg.sender, 6);
    }

    function withdraw(uint256 amount) public onlyOwner() {
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "transfer failed");
    }

    function getPitPrice(uint256 amount, uint256 supply) public view returns(uint256) {
        return (amount * BASE_PIT_COST) + (DELTA *  (amount * (supply + (amount * (amount - 1)) / 2)));
    }

    function getPitsOwned(address addr) public view returns(uint256){
        return pitsOwned[addr];
    }

    receive() external payable {}
}