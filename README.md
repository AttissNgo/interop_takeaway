# Exercise
* All state of the game should live on-chain. State includes open games, games currently in progress and completed games.

* Any user can submit a transaction to the network to invite others to start a game (i.e. create an open game).

* Other users may submit transactions to accept invitations. When an invitation is accepted, the game starts.

* The roles of “X” and “O” are decided as follows. The users' public keys are concatenated and the result is hashed. If the first bit of the output is 0, then the game's initiator (whoever posted the invitation) plays "O" and the second player plays "X" and vice versa. “X” has the first move.

* Both users submit transactions to the network to make their moves until the game is complete.

* The game needs to support multiple concurrent games sessions/players.

* Think about security for this contract (you can assume that this contract is upgradable for this question). How would you audit it, create a threat model, deploy and maintain operations for it?

# Deciding "X" and "O"
"The roles of “X” and “O” are decided as follows. The users' public keys are concatenated and the result is hashed. If the first bit of the output is 0, then the game's initiator (whoever posted the invitation) plays "O" and the second player plays "X" and vice versa. “X” has the first move."

This method of determining "X" and "O" is problematic for the following reasons:
1. It requires collecting signed messages from both players and incurs gas costs for extracting public keys from the messages.
2. It incurs storage costs since the signed message of the initiator must be saved in state (or creates complexity if it must be retrieved from an event off-chain). This becomes even more expensive and involes even more transactions if we want the initiator's key to be hidden to prevent the opponent from rejecting games in which they will play second.
3. It is deterministic: for a given initiator and opponent, the result will always be the same.

If we accept a deterministic solution, then it might make sense to use a similar method but use addresses rather than public keys, plus some sort of dynamic value so that "X" is not always the same:
```javascript
        bytes memory concat = abi.encodePacked(addr1, addr2, block.timestamp);
        bytes32 hash = keccak256(concat);
        bool firstBit;
        assembly {
            firstBit := shr(255, hash) // Shift right by 255 bits to isolate the last bit
        }
        return firstBit;
```

However, it should be noted that "X" has the advantage of going first, so using a deterministic method like the code above would still give an advantage to the player who accepts the invitation. It would be better to assign "X" and "O" randomly when the second user accepts the invitation to play. This would require some sort of off-chain source of verifiable randomness.

In keeping with the original specs and to avoid the complexity of adding a callback from an off-chain randomness oracle, I have implemented a version of the method defined above.

# Test
Rudimentary unit tests and invariant tests are implemented in the `test` directory.

Invariants:
- Each game must have 2 different players
- A square can only be claimed once
- Turns must alternate between players 
- O can never have more squares than X
- A finished game (win or draw) cannot be updated
