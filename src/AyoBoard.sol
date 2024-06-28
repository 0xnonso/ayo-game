// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;
import {Ayo} from "./Ayo.sol";
import {Ayo2x6} from "./Ayo2x6.sol";
import {Base64} from "./vendor/Base64.sol";
import {String} from "./vendor/Strings.sol";
import {Utils} from "./vendor/Utils.sol";

/// @title Library for generating SVG art for Ayo board.
library AyoBoard {
    string internal constant SVG_SCAFFOLD = '<svg viewBox="-50 -50 600 600" style="background: #D3D3'
    'D3;" xmlns="http://www.w3.org/2000/svg"> <defs> <radialGradient id="pitGradientPlayer1" cx="50%'
    '" cy="50%" r="50%" fx="50%" fy="50%"> <stop offset="0%" style="stop-color:#8B5A2B; stop-opacity'
    ':1" /> <stop offset="100%" style="stop-color:#4E2C1E; stop-opacity:1" /> </radialGradient> <rad'
    'ialGradient id="pitGradientPlayer2" cx="50%" cy="50%" r="50%" fx="50%" fy="50%"> <stop offset="'
    '0%" style="stop-color:#9B8B7B; stop-opacity:1" /> <stop offset="100%" style="stop-color:#70645E'
    '; stop-opacity:1" /> </radialGradient> <rect id="base-rect" width="50" height="90" x="0" y="0" '
    'rx="15" style="fill:#a06734;fill-opacity:1;stroke-width:0.5;stroke:#a06734" /> <circle id="pit-'
    '0" r="20" fill="url(#pitGradientPlayer1)"/> <circle id="pit-1" r="20" fill="url(#pitGradientPla'
    'yer2)"/> <circle id="seed" r="2" fill="#FFFFF0"/> <g id="score-board-0"> <rect width="50" heigh'
    't="90" x="0" y="0" rx="15" style="fill:#a06734;fill-opacity:1;stroke-width:0.2;stroke:#a06734" '
    '/> <rect width="34" height="78" x="8" y="6" rx="15" fill="url(#pitGradientPlayer1)" /> </g> <g '
    'id="score-board-1"> <rect width="50" height="90" x="0" y="0" rx="15" style="fill:#a06734;fill-o'
    'pacity:1;stroke-width:0.2;stroke:#a06734" /> <rect width="34" height="78" x="8" y="6" rx="15" f'
    'ill="url(#pitGradientPlayer2)" /> </g> </defs> <style> .fade { animation: fadeOut 2s 3s forward'
    's; } .index-label { fill: black; font-size: 12px; font-weight: 600; text-anchor: middle; font-f'
    'amily: "Poppins", sans-serif; } .grow { animation: growIn 2s 3s forwards; } @keyframes fadeOut '
    '{ from { opacity: 1; } to { opacity: 0; } } @keyframes growIn { from { opacity: 0; } to { opaci'
    'ty: 1; } } .orbit { fill: none; stroke: #2E8B57; stroke-width: 1.5; stroke-dasharray: 157; stro'
    'ke-dashoffset: 157; animation: drawCircle 4s linear infinite; } @keyframes drawCircle { 0%, 100'
    '% { stroke-dashoffset: 157; } 50% { stroke-dashoffset: 0; } } </style>';

    function getMetadata(uint256 board, uint256 move) internal pure returns(string memory){
        uint256 newBoard = Ayo.applyMove(board, move);
        string memory image = Base64.encode(bytes(generateSVGBoard(board, newBoard, move)));

        string memory description = string(
            abi.encodePacked(
                "Player ",
                String.toString(uint256(Ayo2x6.getPlayerTurn(board))),
                " sows seeds in pit index ",
                String.toString(move)
            )
        );
        
        return string(
            abi.encodePacked(
                'data:application/json;base64,',
                Base64.encode(
                    abi.encodePacked(
                        '{"name":"Ayo Game Round #',
                        String.toString(Ayo.getGameRounds(board)),
                        '", "description":"',
                        description,
                        '", "image": "',
                        'data:image/svg+xml;base64,',
                        image,
                        '"}'
                    )
                )
            )
        );
    }

    function generateSVGBoard(
        uint256 board, 
        uint256 newBoard, 
        uint256 move
    ) internal pure returns(string memory svg){
        uint256 boardWidth = Ayo.getBoardWidth(board);
        uint256 totalBoardPits = (0x02 * boardWidth) - 0x01;
        move = Ayo.getPitIndex(move, board);
        svg = string(
            abi.encodePacked(
                SVG_SCAFFOLD,
                generateSVGScoreBoard(
                    Ayo.getP0PitsCaptured(board) * 0x04,
                    Ayo.getP0PitsCaptured(newBoard) * 0x04,
                    boardWidth,
                    true
                )
            )
        );
        for(uint256 i = 0; i < boardWidth; i++){
            svg = string(abi.encodePacked(
                svg,
                generateSVGPitUpper(
                    move,
                    totalBoardPits,
                    totalBoardPits - i,
                    Ayo.getPitSeedsNormalised(totalBoardPits - i, board),
                    Ayo.getPitSeedsNormalised(totalBoardPits - i, newBoard),
                    Ayo.getPitOwnerNormalised(totalBoardPits - i, board) != 0x01
                ),
                generateSVGPitLower(
                    move,
                    i,
                    Ayo.getPitSeedsNormalised(i, board),
                    Ayo.getPitSeedsNormalised(i, newBoard),
                    Ayo.getPitOwnerNormalised(i, board) != 0x0
                )
            ));
        }
        svg = string(
            abi.encodePacked(
                svg,
                generateSVGScoreBoard(
                    Ayo.getP1PitsCaptured(board) * 0x04,
                    Ayo.getP1PitsCaptured(newBoard) * 0x04,
                    boardWidth,
                    false
                ),
                '</svg>'
            )
        );
    }

    function generateSVGScoreBoard(
        uint256 oldPitCaptured, 
        uint256 newPitCaptured, 
        uint256 boardWidth, 
        bool p0Board
    ) internal pure returns(string memory svg){
        svg = string(
            abi.encodePacked(
            '<g transform="translate(',
            p0Board ? "0" : String.toString((50 * boardWidth) + 50),
            ' 0)"> <use href="#score-board-',
            p0Board ? "0" : "1",
            '" />'
        ));

        uint256 pitseedMax = Utils.max(oldPitCaptured, newPitCaptured);
        uint256 pitSeedMin = Utils.min(oldPitCaptured, newPitCaptured);
        uint256 diff = pitseedMax - pitSeedMin;
        for(uint256 i = 0; i < pitSeedMin; i++){
            (uint256 x, uint256 y) = getScoreBoardSeedCoord(i);
            svg = string(
                abi.encodePacked(
                    svg, 
                    '<use href="#seed" class="seed" x="', 
                    String.toString(x), 
                    '" y="',
                    String.toString(y), 
                    '"/>'
                )
            );
        }
        string memory seedTrans = oldPitCaptured > newPitCaptured ? 'fade' : 'grow" style="opacity:0;';
        for(uint256 j = 0; j < diff; j++){
            (uint256 x, uint256 y) = getScoreBoardSeedCoord((j + pitSeedMin));
            svg = string(
                abi.encodePacked(
                    svg, 
                    '<use href="#seed" class="seed ', 
                    seedTrans, 
                    '" x="', 
                    String.toString(x), 
                    '" y="', 
                    String.toString(y), 
                    '"/>'
                )
            );
        }
        svg = string(abi.encodePacked(svg, '</g>'));
    }

    function generateSVGPitUpper(
        uint256 move,
        uint256 totalBoardWidth,
        uint256 pitIndex,
        uint256 oldPitSeeds, 
        uint256 newPitSeeds,
        bool captured
    ) internal pure returns(string memory svg) {
        svg = string(abi.encodePacked(
            '<g transform="translate(',
            String.toString(((totalBoardWidth - pitIndex) * 50) + 50),
            ', 0)"> <g> <use href="#base-rect" />'
        ));
        string memory movePit = pitIndex == move ? 'class="orbit"' : 'class=""';
        svg = string(
            abi.encodePacked(
                svg, 
                '<use href="#pit-', 
                captured ? '0" ' : '1" ', 
                movePit, 
                ' x="25" y="23"/> <text x="25" y="-1" class="index-label">',
                String.toString(pitIndex),
                '</text>'
            )
        );
        uint256 pitSeedMax = Utils.max(oldPitSeeds, newPitSeeds);
        uint256 pitSeedMin = Utils.min(oldPitSeeds, newPitSeeds);
        uint256 diff = pitSeedMax - pitSeedMin;
        for(uint256 i = 0; i < pitSeedMin; i++){
            (uint256 x, uint256 y) = getPitSeedCoord(i, true);
            svg = string(
                abi.encodePacked(
                    svg, 
                    '<use href="#seed" class="seed" x="', 
                    String.toString(x), 
                    '" y="', 
                    String.toString(y), 
                    '"/>'
                )
            );
        }
        string memory seedTrans = oldPitSeeds > newPitSeeds ? 'fade' : 'grow" style="opacity:0;';
        for(uint256 j = 0; j < diff; j++){
            (uint256 x, uint256 y) = getPitSeedCoord(j + pitSeedMin, true);
            svg = string(
                abi.encodePacked(
                    svg, 
                    '<use href="#seed" class="seed ', 
                    seedTrans, 
                    '" x="', 
                    String.toString(x), 
                    '" y="',
                    String.toString(y), 
                    '"/>'
                )
            );
        }
    }

    function generateSVGPitLower(
        uint256 move, 
        uint256 pitIndex,
        uint256 oldPitSeeds, 
        uint256 newPitSeeds,
        bool captured
    ) internal pure returns(string memory svg) {
        string memory movePit = pitIndex == move ? 'class="orbit"' : 'class=""';
        string memory id = captured ? '1" ' : '0" ';
        svg = string(
            abi.encodePacked(
                '<use href="#pit-', 
                id, 
                movePit, 
                ' x="25" y="67"/> <text x="25" y="100" class="index-label">',
                String.toString(pitIndex),
                '</text>'
            )
        );
        uint256 pitSeedMax = Utils.max(oldPitSeeds, newPitSeeds);
        uint256 pitSeedMin = Utils.min(oldPitSeeds, newPitSeeds);
        uint256 diff = pitSeedMax - pitSeedMin;
        for(uint256 i = 0; i < pitSeedMin; i++){
            (uint256 x, uint256 y) = getPitSeedCoord(i, false);
            svg = string(
                abi.encodePacked(
                    svg, 
                    '<use href="#seed" class="seed" x="', 
                    String.toString(x), 
                    '" y="',
                    String.toString(y),
                    '"/>'
                )
            );
        }
        string memory seedTrans = oldPitSeeds > newPitSeeds ? 'fade' : 'grow" style="opacity:0;';
        for(uint256 j = 0; j < diff; j++){
            (uint256 x, uint256 y) = getPitSeedCoord(j + pitSeedMin, false);
            svg = string(
                abi.encodePacked(
                    svg, 
                    '<use href="#seed" class="seed ', 
                    seedTrans, 
                    '" x="', 
                    String.toString(x), 
                    '" y="', 
                    String.toString(y), 
                    '"/>'
                )
            );
        }
        svg = string(abi.encodePacked(svg, '</g> </g>'));
    }

    function getPitSeedCoord(uint256 index, bool row1) internal pure returns(uint256 x, uint256 y){
        uint256 seedCoordsX = 0x191E14191E1419141E0F0F0F14191E232323231E19140F14191E0F23230F0A00;
        uint256 seedCoordsY = row1 
            ? 0x1919191414141E1E1E19140F0F0F0F0F14191E2323231E0A0A0A0A0A23231400 
            : 0x4545454040404A4A4A45403B3B3B3B3B40454A4F4F4F4A36363636364F4F4000;
        assembly{
            x := byte(index, seedCoordsX)
            y := byte(index, seedCoordsY)
        }
    }

    function getScoreBoardSeedCoord(uint256 index) internal pure returns(uint256 x, uint256 y){
         x = ((index % 0x04) * 0x05) + 0x11; // 
         y = ((index / 0x04) * 0x05) + 0x19;
    }
}