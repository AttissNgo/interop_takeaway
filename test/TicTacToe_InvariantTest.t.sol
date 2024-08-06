// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {TicTacToe} from "../src/TicTacToe.sol";

contract Handler is Test {

    TicTacToe public ttt;
    uint256 public gameId;
    address public x;
    address public o;
    uint256[] public squaresX;
    uint256[] public squaresO;
    uint256 public lastRoundPlayed;

    constructor(address _ttt, uint256 _gameId, address _x, address _o) {
        ttt = TicTacToe(_ttt);
        gameId = _gameId;
        x = _x;
        o = _o;
    }

    function play(uint256 randomPlayer, uint256 position) public {
        address player = randomPlayer % 2 == 0 ? x : o;
        position = bound(position, 0, 8);
        vm.prank(player);
        ttt.claimSquare(gameId, position);

        if (player == x) {
            squaresX.push(position);
        } else {
            squaresO.push(position);
        }

        assertTrue(squaresX.length == squaresO.length || squaresX.length == squaresO.length + 1); // will fail if system allows player to claim square out of turn

        TicTacToe.Game memory game = ttt.getGame(gameId);
        if (game.status == TicTacToe.GameStatus.Win || game.status == TicTacToe.GameStatus.Draw) {
            lastRoundPlayed = game.roundsPlayed;
        }
    }

    function getSquares() public view returns (uint256[] memory, uint256[] memory) {
        return (squaresX, squaresO);
    }

}

contract TicTacToeInvariantTest is Test {
    
    TicTacToe public ttt;
    Handler public handler;

    address player1 = makeAddr("player1");
    address player2 = makeAddr("player2");

    function setUp() public {
        ttt = new TicTacToe();

        vm.prank(player1);
        uint256 gameId = ttt.challenge(player2);
        vm.prank(player2);
        ttt.acceptChallenge(gameId);
        TicTacToe.Game memory game = ttt.getGame(gameId);
        address x_ = game.x == player1 ? player1 : player2;
        address o_ = game.x == player1 ? player2 : player1;

        handler = new Handler(address(ttt), gameId, x_, o_);
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = Handler.play.selector;
        targetSelector(FuzzSelector({addr: address(handler), selectors: selectors}));
        targetContract(address(handler));
    }

    function invariant_game_has_2_players() public view {
        TicTacToe.Game memory game = ttt.getGame(handler.gameId());
        assertTrue(game.player1 != address(0));
        assertTrue(game.player2 != address(0));
        assertTrue(game.x == game.player1 || game.x == game.player2);
        assertTrue(game.player1 != game.player2);
    }

    function invariant_O_cannot_have_more_squares_than_X() public view {
        (uint256[] memory squaresX, uint256[] memory squaresO) = handler.getSquares();
        assertTrue(squaresO.length <= squaresX.length);
    }

    function invariant_square_can_only_be_claimed_once() public view {
        (uint256[] memory squaresX, uint256[] memory squaresO) = handler.getSquares();
        for (uint i; i < squaresX.length; ++i) {
            for (uint j; j < squaresO.length; ++j) {
                assertTrue(squaresX[i] != squaresO[j]);
            }
        }
    }

    function invariant_finished_game_cannot_be_updated() public view {
        TicTacToe.Game memory game = ttt.getGame(handler.gameId());
        assertLe(game.roundsPlayed, 9); 

        if (game.roundsPlayed == 9) {
            assertTrue(uint(game.status) != uint(TicTacToe.GameStatus.Open)); // must be either Win or Draw
        }
        
        if (game.status != TicTacToe.GameStatus.Open) {
            assertEq(handler.lastRoundPlayed(), game.roundsPlayed);
        }
    }

}