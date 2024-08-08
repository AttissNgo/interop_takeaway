// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

contract TicTacToe {

    enum GameStatus {
        Open,
        Win,
        Draw
    }

    struct Game {
        address player1;
        address player2;
        address x;
        uint8 roundsPlayed;
        GameStatus status;
        address[9] board;
    }

    Game[] private games;

    error TicTacToe__InvalidOpponent();
    error TicTacToe__NotChallenged();
    error TicTacToe__GameAlreadyInProgress();
    error TicTacToe__OutOfTurn();
    error TicTacToe__InvalidPosition();
    error TicTacToe__SquareNotOpen();
    error TicTacToe__InvalidPlayer();
    error TicTacToe__GameNotOpen();

    event Challenged(address indexed player1, address indexed player2, uint256 indexed gameId);
    event ChallengeAccepted(address indexed player1, address indexed player2, uint256 indexed gameId);
    event SquareClaimed(
        address indexed player1, 
        address indexed player2, 
        uint256 indexed gameId, 
        GameStatus status
    );

    function challenge(address opponent) external returns (uint256 gameId) {
        if (opponent == address(0) || opponent == msg.sender) revert TicTacToe__InvalidOpponent();

        Game memory game;
        game.player1 = msg.sender;
        game.player2 = opponent;
        games.push(game);
        gameId = games.length - 1;

        emit Challenged(msg.sender, opponent, gameId);
    }

    function acceptChallenge(uint256 gameId) external {
        Game storage game = games[gameId];
        if (msg.sender != game.player2) revert TicTacToe__NotChallenged();
        if (game.x != address(0)) revert TicTacToe__GameAlreadyInProgress();

        bytes memory concat = abi.encodePacked(game.player1, game.player2, block.timestamp);
        bytes32 hash = keccak256(concat);
        bool player1IsX;
        assembly {
            player1IsX := shr(255, hash) // Shift right by 255 bits to isolate the last bit
        }
        
        game.x = player1IsX ? game.player1 : game.player2;

        emit ChallengeAccepted(game.player1, game.player2, gameId);
    }

    function claimSquare(uint256 gameId, uint256 position) external { 
        if (position > 8) {
            revert TicTacToe__InvalidPosition();
        }

        Game storage game = games[gameId];
        
        if (msg.sender != game.player1 && msg.sender != game.player2) revert TicTacToe__InvalidPlayer();
        if (game.status != GameStatus.Open || game.x == address(0)) revert TicTacToe__GameNotOpen();
        bool isX = msg.sender == game.x;
        bool isXTurn = game.roundsPlayed % 2 == 0;
        if (isX && !isXTurn || !isX && isXTurn) revert TicTacToe__OutOfTurn();
        if (game.board[position] != address(0)) revert TicTacToe__SquareNotOpen();
        
        game.board[position] = msg.sender;
        ++game.roundsPlayed;
        GameStatus status = updateGameStatus(game, position);
        if (status != game.status) {
            game.status = status;
        }

        emit SquareClaimed(game.player1, game.player2, gameId, game.status);
    }

    function updateGameStatus(Game memory game, uint256 position) private view returns (GameStatus) {
        if (game.roundsPlayed < 5) return GameStatus.Open;

        // check vertical path
        uint i = position < 3 ? position : (position - 3) % 3; // gets the index of the column 
        if (game.board[i] == game.board[i + 3] && game.board[i] == game.board[i + 6]) {
            return GameStatus.Win;
        }   

        // check horzontal path
        i = position - (position % 3);
        if (game.board[i] == game.board[i + 1] && game.board[i] == game.board[i + 2]) {
            return GameStatus.Win;
        }   

        // check diagonal paths
        if (position % 2 == 0 && game.board[4] == msg.sender) {
            if ((game.board[0] == msg.sender && game.board[8] == msg.sender) || 
                (game.board[2] == msg.sender && game.board[6] == msg.sender)) 
            {
                return GameStatus.Win;
            }
        }

        if (game.roundsPlayed == 9) return GameStatus.Draw;

        return GameStatus.Open;
    }

    function getGame(uint256 gameId) public view returns (Game memory) {
        return games[gameId];
    }

    function getAllGames() public view returns (Game[] memory) {
        return games;
    }

}
