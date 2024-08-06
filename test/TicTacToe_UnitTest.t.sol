// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {TicTacToe} from "../src/TicTacToe.sol";

contract TicTacToeUnitTest is Test {

    TicTacToe public ttt;

    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");

    modifier openGame() {
        vm.pauseGasMetering();
        vm.prank(alice);
        uint gameId = ttt.challenge(bob);
        vm.prank(bob);
        ttt.acceptChallenge(gameId);
        vm.resumeGasMetering();
        _;
    }

    function setUp() public {
        ttt = new TicTacToe();
    }

    function test_challenge() public {
        uint256 numGamesBefore = ttt.getAllGames().length;

        vm.prank(alice);
        uint256 gameId = ttt.challenge(bob);

        assertEq(ttt.getAllGames().length, numGamesBefore + 1); // game stored
        TicTacToe.Game memory game = ttt.getGame(gameId);
        assertEq(game.player1, alice); // players initialized
        assertEq(game.player2, bob); // players initialized
        assertEq(game.x, address(0)); // "X" is uninitialized
        assertEq(uint(game.status), uint(TicTacToe.GameStatus.Open));
        assertEq(game.roundsPlayed, 0); // no rounds played
        for (uint i; i < game.board.length; ++i) {
            assertEq(game.board[i], address(0)); // all spaces uninitialized
        }
    }

    function test_challenge_revert() public {
        // invalid opponent - zero address
        vm.expectRevert(TicTacToe.TicTacToe__InvalidOpponent.selector);
        vm.prank(alice);
        ttt.challenge(address(0));
        // invalid opponent - same as initiator
        vm.expectRevert(TicTacToe.TicTacToe__InvalidOpponent.selector);
        vm.prank(alice);
        ttt.challenge(alice);
    }

    function test_acceptChallenge() public {
        vm.prank(alice);
        uint256 gameId = ttt.challenge(bob);

        vm.prank(bob);
        ttt.acceptChallenge(gameId);

        TicTacToe.Game memory game = ttt.getGame(gameId);
        assertFalse(game.x == address(0)); // x has been initialized
    }

    function test_acceptChallenge_revert() public {
        vm.prank(alice);
        uint256 gameId = ttt.challenge(bob);
        
        // not challenged
        vm.expectRevert(TicTacToe.TicTacToe__NotChallenged.selector);
        ttt.acceptChallenge(gameId);

        // game already in progress
        vm.prank(bob);
        ttt.acceptChallenge(gameId);
        vm.expectRevert(TicTacToe.TicTacToe__GameAlreadyInProgress.selector);
        vm.prank(bob);
        ttt.acceptChallenge(gameId);
    }

    function test_claimSquare() public openGame {
        TicTacToe.Game memory game = ttt.getGame(0);
        address x = game.x == alice ? alice : bob;
        assertEq(game.roundsPlayed, 0);
        assertEq(game.board[4], address(0));

        vm.prank(x);
        ttt.claimSquare(0, 4);

        game = ttt.getGame(0);
        assertEq(game.roundsPlayed, 1);
        assertEq(game.board[4], x);
    }

    function test_claimSquare_revert() public openGame {
        TicTacToe.Game memory game = ttt.getGame(0);
        address x = game.x == alice ? alice : bob;
        address o = game.x == alice ? bob : alice;
        
        // invalid position
        vm.expectRevert(TicTacToe.TicTacToe__InvalidPosition.selector);
        vm.prank(x);
        ttt.claimSquare(0, 9);

        // invalid player
        vm.expectRevert(TicTacToe.TicTacToe__InvalidPlayer.selector);
        ttt.claimSquare(0, 4);

        // out of turn
        vm.expectRevert(TicTacToe.TicTacToe__OutOfTurn.selector);
        vm.prank(o);
        ttt.claimSquare(0, 4);

        // square already taken
        vm.prank(x);
        ttt.claimSquare(0, 4);
        vm.expectRevert(TicTacToe.TicTacToe__SquareNotOpen.selector);
        vm.prank(o);
        ttt.claimSquare(0, 4);

        // game already finished
        vm.prank(o);
        ttt.claimSquare(0, 0);
        vm.prank(x);
        ttt.claimSquare(0, 3);
        vm.prank(o);
        ttt.claimSquare(0, 1);
        vm.prank(x);
        ttt.claimSquare(0, 5);
        game = ttt.getGame(0);
        assertEq(uint(game.status), uint(TicTacToe.GameStatus.Win));
        vm.expectRevert(TicTacToe.TicTacToe__GameNotOpen.selector);
        vm.prank(o);
        ttt.claimSquare(0, 5);
        
        // challenge not accepted
        vm.prank(alice);
        uint256 newGameId = ttt.challenge(bob);
        vm.expectRevert(TicTacToe.TicTacToe__GameNotOpen.selector);
        vm.prank(bob);
        ttt.claimSquare(newGameId, 4);
    }

    function test_win() public openGame {
        TicTacToe.Game memory game = ttt.getGame(0);
        address x = game.x == alice ? alice : bob;
        address o = game.x == alice ? bob : alice;
        assertEq(uint(game.status), uint(TicTacToe.GameStatus.Open));

        vm.prank(x);
        ttt.claimSquare(0, 4);
        vm.prank(o);
        ttt.claimSquare(0, 1);
        vm.prank(x);
        ttt.claimSquare(0, 0);
        vm.prank(o);
        ttt.claimSquare(0, 2);
        vm.prank(x);
        ttt.claimSquare(0, 8);

        game = ttt.getGame(0);
        assertEq(uint(game.status), uint(TicTacToe.GameStatus.Win));
    }

    function test_draw() public openGame {
        TicTacToe.Game memory game = ttt.getGame(0);
        address x = game.x == alice ? alice : bob;
        address o = game.x == alice ? bob : alice;

        vm.prank(x);
        ttt.claimSquare(0, 0);
        vm.prank(o);
        ttt.claimSquare(0, 1);
        vm.prank(x);
        ttt.claimSquare(0, 4);
        vm.prank(o);
        ttt.claimSquare(0, 2);
        vm.prank(x);
        ttt.claimSquare(0, 5);
        vm.prank(o);
        ttt.claimSquare(0, 3);
        vm.prank(x);
        ttt.claimSquare(0, 6);
        vm.prank(o);
        ttt.claimSquare(0, 8);
        vm.prank(x);
        ttt.claimSquare(0, 7);

        game = ttt.getGame(0);
        assertEq(uint(game.status), uint(TicTacToe.GameStatus.Draw));
    }


}