// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "../lib/forge-std/src/Test.sol";
import {Game} from "../src/Game.sol";

contract GameTest is Test {
    Game public game;

    address public deployer;
    address public player1;
    address public player2;
    address public player3;
    address public maliciousActor;

    // Initial game parameters for testing
    uint256 public constant INITIAL_CLAIM_FEE = 0.1 ether; // 0.1 ETH
    uint256 public constant GRACE_PERIOD = 1 days; // 1 day in seconds
    uint256 public constant FEE_INCREASE_PERCENTAGE = 10; // 10%
    uint256 public constant PLATFORM_FEE_PERCENTAGE = 5; // 5%

    function setUp() public {
        deployer = makeAddr("deployer");
        player1 = makeAddr("player1");
        player2 = makeAddr("player2");
        player3 = makeAddr("player3");
        maliciousActor = makeAddr("maliciousActor");

        vm.deal(deployer, 10 ether);
        vm.deal(player1, 10 ether);
        vm.deal(player2, 10 ether);
        vm.deal(player3, 10 ether);
        vm.deal(maliciousActor, 10 ether);

        vm.startPrank(deployer);
        game = new Game(
            INITIAL_CLAIM_FEE,
            GRACE_PERIOD,
            FEE_INCREASE_PERCENTAGE,
            PLATFORM_FEE_PERCENTAGE
        );
        vm.stopPrank();
    }

    function testConstructor_RevertInvalidGracePeriod() public {
        vm.expectRevert("Game: Grace period must be greater than zero.");
        new Game(
            INITIAL_CLAIM_FEE,
            0,
            FEE_INCREASE_PERCENTAGE,
            PLATFORM_FEE_PERCENTAGE
        );
    }

    function testClaimThrone_RevertInsufficientValue() external {
        uint256 claimFee = game.claimFee();
        uint256 revertFee = claimFee - 1;

        vm.expectRevert("Game: Insufficient ETH sent to claim the throne.");
        vm.startPrank(player1);
        game.claimThrone{value: revertFee}();
        vm.stopPrank();
    }

    function testClaimThrone_RevertAlreadyKing() external {
        uint256 claimFee = game.claimFee();
        address currentKing = game.currentKing();
        vm.deal(currentKing, claimFee);
        vm.expectRevert("Game: You are already the king. No need to re-claim.");
        vm.startPrank(currentKing);
        game.claimThrone{value: claimFee}();
        vm.stopPrank();
    }

    function testClaimThrone_EndToEndTest() external {
        uint256 claimFee = game.claimFee();
        uint256 platformFeesBalance = game.platformFeesBalance();
        uint256 pot = game.pot();
        uint256 totalClaims = game.totalClaims();

        vm.startPrank(player1);
        game.claimThrone{value: claimFee}();
        vm.stopPrank();

        assertEq(
            game.currentKing(),
            player1,
            "Player 1 should be the current king"
        );
        assertEq(
            game.claimFee(),
            claimFee + (claimFee * game.feeIncreasePercentage()) / 100,
            "Claim fee should increase by feeIncreasePercentage"
        );
        assertEq(
            game.platformFeesBalance(),
            platformFeesBalance +
                (claimFee * game.platformFeePercentage()) /
                100,
            "Platform fees balance should be updated"
        );
        assertEq(
            game.pot(),
            pot + (claimFee * (100 - game.platformFeePercentage())) / 100,
            "Pot should be updated with claim fee minus platform fees"
        );
        assertEq(
            game.totalClaims(),
            totalClaims + 1,
            "Total claims should be incremented"
        );
        assertEq(
            game.lastClaimTime(),
            block.timestamp,
            "Last claim time should be updated"
        );
    }
}
