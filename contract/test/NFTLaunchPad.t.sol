// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../lib/forge-std/src/Test.sol";
import "../src/NFTLaunchPad.sol";

contract NFTLaunchPadTes is Test {
    LaunchPadFactory public factory;
    LaunchPad public launchpad;

    function setUp() public {
        factory = new LaunchPadFactory(address(this));
    }

    function testWhitelistAddress() public {
        factory.whitelistAddress(address(this));
    }

    function testFailedCreateLaunchPadWithoutFee() public {
        testWhitelistAddress();
        factory.createLaunchPad("Cream", "CM", "http://cream.com");
    }

    function testCreateLaunchPad() public {
        testWhitelistAddress();
        address newlaunchpad = factory.createLaunchPad{value: 0.001 ether}(
            "Cream",
            "SM",
            "http://cream.com"
        );
        launchpad = LaunchPad(payable(newlaunchpad));
    }

    function testStartLaunchPad() public {
        testCreateLaunchPad();
        launchpad.startLaunchPad(5 minutes, 0.0001 ether, 0.002 ether);
    }

    function testFailedStartLaunchPad() public {
        testCreateLaunchPad();
        vm.prank(address(0x01));
        launchpad.startLaunchPad(5 minutes, 0.0001 ether, 100 ether);
    }

    function testFailedDepositETH() public {
        testStartLaunchPad();
        launchpad.depositETH{value: 0.001 ether}(1);
    }

    function testDepositETH() public {
        testStartLaunchPad();
        vm.warp(block.timestamp + 1 minutes);
        launchpad.depositETH{value: 0.0003 ether}(3);
        vm.deal(address(0x03), 100 ether);
        vm.prank(address(0x03));
        launchpad.depositETH{value: 0.0003 ether}(3);
    }

    function testFailedDepositETHBuyMoreThanAvaialble() public {
        testStartLaunchPad();
        vm.warp(block.timestamp + 1 minutes);
        launchpad.depositETH{value: 0.056 ether}(3);
    }

    function testFailDepositETHIncorrectValue() public {
        testStartLaunchPad();
        vm.warp(block.timestamp + 1 minutes);
        launchpad.depositETH{value: 0.00001 ether}(1);
    }

    function testFailWithdrawNFTLaunchPadNotEnded() public {
        testDepositETH();
        launchpad.withdrawNFT();
    }

    function testFailWithdrawNFTDidntSuscribe() public {
        testDepositETH();
        vm.prank(address(0x02));
        vm.warp(block.timestamp + 5 minutes);
        launchpad.withdrawNFT();
    }

    function testWithdrawNFT() public {
        testDepositETH();
        vm.warp(block.timestamp + 5 minutes);
        launchpad.withdrawNFT();
        vm.prank(address(0x03));
        launchpad.withdrawNFT();
    }

    function testTransferLeftoverNFTBeforeWithdraw() public {
        testDepositETH();
        vm.warp(block.timestamp + 5 minutes);
        launchpad.transferLeftoverNFT(address(this));
        launchpad.withdrawNFT();
        vm.prank(address(0x03));
        launchpad.withdrawNFT();
    }

    function testWithdrawETH() public {
        testDepositETH();
        launchpad.withdrawETH(
            payable(address(this)),
            address(launchpad).balance
        );
    }

    function testTokenURI() public {
        testWithdrawNFT();
        launchpad.tokenURI(5);
    }

    receive() external payable {}
}
