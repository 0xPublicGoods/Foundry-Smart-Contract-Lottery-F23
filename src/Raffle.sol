// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

/**
 * @title Raffle Contract
 * @author 0xPublicGoods
 * @notice Raffle Contract is for creating a Sample Raffle
 * @dev Implements Chainlink VRFv2
 */
contract Raffle is VRFConsumerBaseV2 {
    /** Errors */
    error Raffle__NotEnoughETHSent();
    error Raffle__TransferFailed();
    error Raffle__RaffleNotOpen();

    /** Type Declarations */
    enum RaffleState {
        OPEN,
        CALCULATING
    }

    /** State Variables */
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;

    uint256 private immutable i_entranceFee;
    // @dev duration of the raffle in seconds
    uint256 private immutable i_interval;
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    bytes32 private immutable i_gasLane;
    uint64 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;

    address payable[] private s_players;
    uint256 private s_lastTimestamp;
    address private s_recentWinner;
    RaffleState private s_raffleState;

    /** Events */
    event RaffleEntered(address indexed player);
    event WinnerPicked(address indexed winner);

    /** Constructor */
    constructor(
        uint256 entranceFee,
        uint256 interval,
        address vrfCoordinator,
        bytes32 gasLane,
        uint64 subscriptionId,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2(vrfCoordinator) {
        i_entranceFee = entranceFee;
        i_interval = interval;
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinator);
        i_gasLane = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;

        s_raffleState = RaffleState.OPEN;
        s_lastTimestamp = block.timestamp;
    }

    /** Methods */
    function enterRaffle() external payable {
        if (msg.value < i_entranceFee) {
            revert Raffle__NotEnoughETHSent();
        }
        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle__RaffleNotOpen();
        }

        s_players.push(payable(msg.sender));

        emit RaffleEntered(msg.sender);
    }

    /**
     * 1. get a random number
     * 2. use random number to pick a player
     * 3. be called automatically
     */
    function pickWinner() external {
        // check to see if enough time has passed by comparing it to interval and last time a winner was picked
        if ((block.timestamp - s_lastTimestamp) < i_interval) {
            revert();
        }
        s_raffleState = RaffleState.CALCULATING;

        // 1. get a random number
        uint256 requestId = i_vrfCoordinator.requestRandomWords(
            i_gasLane, // gas lane
            i_subscriptionId, // id funded with link
            REQUEST_CONFIRMATIONS, // block confirmations
            i_callbackGasLimit, // dont overspend on call
            NUM_WORDS // #of random numbers/words
        );
    }

    function fulfillRandomWords(
        uint256 requestId,
        uint256[] memory randomWords
    ) internal override {
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        address payable winner = s_players[indexOfWinner];
        s_recentWinner = winner;
        s_raffleState = RaffleState.OPEN;

        // reset the players array
        s_players = new address payable[](0);
        // reset the timer
        s_lastTimestamp = block.timestamp;

        (bool success, ) = winner.call{value: address(this).balance}("");
        if (!success) {
            revert Raffle__TransferFailed();
        }

        emit WinnerPicked(winner);
        // s_raffleState = RaffleState.OPEN; -> why not over here once payment is successful?
        // do we get stuck in a RaffleState.CALCULATING forever if it reverts?
        // maybe we will refactor later...
    }

    /** Getters */

    function getEntranceFee() external view returns (uint256) {
        return i_entranceFee;
    }
}
