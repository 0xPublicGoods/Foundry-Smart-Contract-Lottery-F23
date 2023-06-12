// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

/** Imports */
import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/Script.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {Raffle} from "../../src/Raffle.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";

contract RaffleTest is Test {
    /** Events */
    event RaffleEntered(address indexed player);

    Raffle raffle;
    HelperConfig helperConfig;

    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint64 subscriptionId;
    uint32 callbackGasLimit;
    address link;

    address public PLAYER = makeAddr("player");
    uint256 public constant STARTING_PLAYER_BALANCE = 10 ether;

    function setUp() external {
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.run();

        (
            entranceFee,
            interval,
            vrfCoordinator,
            gasLane,
            subscriptionId,
            callbackGasLimit,
            link,

        ) = helperConfig.activeNetworkConfig();

        vm.deal(PLAYER, STARTING_PLAYER_BALANCE);
    }

    function testRaffleInitsWithOpenState() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN); // why cant we use assertEq (the method itself doesnt use enum returns?)
    }

    //////////////////
    // Enter Raffle //
    //////////////////

    function testRaffleRevertsWhenYouDontPayEnough() public {
        // arrange
        vm.prank(PLAYER);
        // act / assert
        vm.expectRevert(Raffle.Raffle__NotEnoughETHSent.selector);
        raffle.enterRaffle();
    }

    function testRaffleRecordsPlayerWhenTheyEnter() public {
        vm.prank(PLAYER);

        raffle.enterRaffle{value: entranceFee}();
        address playerRecorded = raffle.getPlayer(0);

        assertEq(raffle.getPlayers().length, 1);
        assertEq(playerRecorded, PLAYER);
    }

    function testEmitsEventOnEnter() public {
        vm.expectEmit(true, false, false, false, address(raffle));
        emit RaffleEntered(PLAYER);

        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
    }

    function testCantEnterRaffleWhenCalculating() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();

        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");

        // assert(raffle.getRaffleState() == Raffle.RaffleState.CALCULATING);
        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
        raffle.enterRaffle{value: entranceFee}();
    }

    /////////////////
    // checkUpkeep //
    /////////////////

    function testCheckUpkeepReturnsFalseIfItHasNoBalance() public {
        // Arrange
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        // Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        // Assert
        assert(!upkeepNeeded);
    }

    function testCheckUpkeepShouldReturnFalseIfRaffleNotOpen() public {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();

        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        (bool upkeepNeeded1, ) = raffle.checkUpkeep("");
        assert(upkeepNeeded1 == true);

        raffle.performUpkeep("");

        // Act
        (bool upkeepNeeded2, ) = raffle.checkUpkeep("");

        // Assert
        assert(upkeepNeeded2 == false);
    }

    function testCheckUpkeepReturnsFalseIfEnoughTimeHasntPassed() public {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();

        // vm.warp(block.timestamp + interval + 1);
        // vm.roll(block.number + 1);

        // Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        // Assert
        assert(!upkeepNeeded);
    }

    function testChekUpkeepReturnstrueIfParametersAreGood() public {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();

        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        // Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        // Assert
        assert(upkeepNeeded);
    }

    ///////////////////
    // performUpkeep //
    ///////////////////

    function testPerformUpkeepCanOnlyRunIfCheckUpkeepIsTrue() public {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();

        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        // Act
        raffle.performUpkeep("");

        // Assert
        assert(raffle.getRaffleState() == Raffle.RaffleState.CALCULATING);
    }

    function testPerformUpkeepRevertsIfCheckUpkeepIsFalse() public {
        uint256 balance = 0;
        uint256 numPlayers = 0;
        uint256 raffleState = 0;

        // Act / Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                Raffle.Raffle__UpkeepNotNeeded.selector,
                balance,
                numPlayers,
                raffleState
            )
        );
        raffle.performUpkeep("");
    }

    modifier entered() {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        _;
    }

    modifier enoughTimePassed() {
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
    }

    modifier skipFork() {
        if (block.chainid != 31337) {
            return;
        }
        _;
    }

    function testPerfromUpkeepUpdatesRaffleStateAndEmitsRequestId()
        public
        entered
        enoughTimePassed
    {
        // Act
        vm.recordLogs();
        raffle.performUpkeep(""); // emits requestId

        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1]; //topics[0] refers to entire event, topics[1] refers to requestId (first topic)

        Raffle.RaffleState raffleState = raffle.getRaffleState();

        // Assert
        assert(raffle.getRaffleState() == Raffle.RaffleState.CALCULATING);
        assert(uint256(requestId) > 0);

        assert(uint256(raffleState) == 1); // 1 == calculating ,0==open
    }

    /////////////////////////
    /// fulfillRandomWords //
    /////////////////////////

    function testFulfillRandomWordsCanOnlyBeCalledAfterPerformUpkeep(
        uint256 randomRequestId
    ) public entered enoughTimePassed skipFork {
        vm.expectRevert("nonexistent request");
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(
            randomRequestId,
            address(raffle)
        );
    }

    function testFulfillRandomWordsPicksAWinnerResetsAndSendsMoney()
        public
        entered
        enoughTimePassed // order matters I think
        skipFork
    {
        console.log("check modifier order");
        // Arrange
        uint256 additionalEntrants = 5;
        uint256 startingIndex = 1;

        for (
            uint256 i = startingIndex;
            i < startingIndex + additionalEntrants;
            i++
        ) {
            address player = address(uint160(i));
            hoax(player, STARTING_PLAYER_BALANCE);
            raffle.enterRaffle{value: entranceFee}();
        }

        uint256 prize = entranceFee * (additionalEntrants + 1);

        vm.recordLogs();
        raffle.performUpkeep(""); // emits requestId
        Vm.Log[] memory entries = vm.getRecordedLogs(); // counts everything as bytes32
        bytes32 requestId = entries[1].topics[1];

        uint256 previousTimestamp = raffle.getLastTimestamp();

        //pretend to be chainlink vrf and fulfill request

        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(
            uint256(requestId),
            address(raffle)
        );

        // Assert

        assert(uint256(raffle.getRaffleState()) == 0); // 1 == calculating ,0==open
        assert(raffle.getRecentWinner() != address(0));
        assert(raffle.getPlayers().length == 0);
        assert(raffle.getLastTimestamp() > previousTimestamp);
        assert(
            raffle.getRecentWinner().balance ==
                prize + STARTING_PLAYER_BALANCE - entranceFee
        );
    }
}
