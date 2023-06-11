// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

/**
 * @title Raffle Contract
 * @author 0xPublicGoods
 * @notice Raffle Contract is for creating a Sample Raffle
 * @dev Implements Chainlink VRFv2
 */
contract Raffle {
    /** Errors */
    error Raffle__NotEnoughETHSent();

    /** State */
    uint256 private i_entranceFee;
    address payable[] private s_players;

    /** Events */
    event RaffleEntered(address indexed player);

    constructor(uint256 entranceFee) {
        i_entranceFee = entranceFee;
    }

    function enterRaffle() external payable {
        if (msg.value < i_entranceFee) {
            revert Raffle__NotEnoughETHSent();
        }

        s_players.push(payable(msg.sender));

        emit RaffleEntered(msg.sender);
    }

    function pickWinner() public {}

    /** Getters */

    function getEntranceFee() external view returns (uint256) {
        return i_entranceFee;
    }
}
