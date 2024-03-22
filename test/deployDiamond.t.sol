// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../contracts/interfaces/IDiamondCut.sol";
import "../contracts/facets/DiamondCutFacet.sol";
import "../contracts/facets/DiamondLoupeFacet.sol";
import "../contracts/facets/OwnershipFacet.sol";

import "../contracts/facets/ERC20Facet.sol";
import "../contracts/facets/StakingFacet.sol";

import "../contracts/WOWToken.sol";
import "forge-std/Test.sol";
import "../contracts/Diamond.sol";

import "../contracts/libraries/LibAppStorage.sol";

contract DiamondDeployer is Test, IDiamondCut {
    //contract types of facets to be deployed
    Diamond diamond;
    DiamondCutFacet dCutFacet;
    DiamondLoupeFacet dLoupe;
    OwnershipFacet ownerF;
    ERC20Facet erc20Facet;
    StakingFacet sFacet;
    WOWToken wow;

    address A = address(0xa);
    address B = address(0xb);
    address C = address(0xc);

    StakingFacet boundStaking;
    ERC20Facet erc20Bound;

    function setUp() public {
        //deploy facets
        dCutFacet = new DiamondCutFacet();
        diamond = new Diamond(address(this), address(dCutFacet));
        dLoupe = new DiamondLoupeFacet();
        ownerF = new OwnershipFacet();
        erc20Facet = new ERC20Facet();
        sFacet = new StakingFacet();
        wow = new WOWToken();

        //upgrade diamond with facets

        //build cut struct
        FacetCut[] memory cut = new FacetCut[](4);

        cut[0] = (
            FacetCut({
                facetAddress: address(dLoupe),
                action: FacetCutAction.Add,
                functionSelectors: generateSelectors("DiamondLoupeFacet")
            })
        );

        cut[1] = (
            FacetCut({
                facetAddress: address(ownerF),
                action: FacetCutAction.Add,
                functionSelectors: generateSelectors("OwnershipFacet")
            })
        );
        cut[2] = (
            FacetCut({
                facetAddress: address(sFacet),
                action: FacetCutAction.Add,
                functionSelectors: generateSelectors("StakingFacet")
            })
        );

        cut[3] = (
            FacetCut({
                facetAddress: address(erc20Facet),
                action: FacetCutAction.Add,
                functionSelectors: generateSelectors("ERC20Facet")
            })
        );

        //upgrade diamond
        IDiamondCut(address(diamond)).diamondCut(cut, address(0x0), "");

        //set rewardToken
        diamond.setRewardToken(address(wow));
        A = mkaddr("staker a");
        B = mkaddr("staker b");
        C = mkaddr("WOW Owner");

        //mint test tokens
        ERC20Facet(address(diamond)).mintTo(A);
        ERC20Facet(address(diamond)).mintTo(B);
        wow.mint(C, 100_000_000e18);

        boundStaking = StakingFacet(address(diamond));
        erc20Bound = ERC20Facet(address(diamond));
    }

    function testStaking() public {
        switchSigner(A);
        uint256 balanceBeforeStaking = erc20Bound.balanceOf(A);
        console.log("A", balanceBeforeStaking);

        uint256 wowBalance = wow.balanceOf(C);
        assertTrue(wowBalance == 100_000_000e18, "WOW balance was not minted");

        uint256 rewardsBeforeStake = boundStaking.checkRewards(A);
        assertTrue(rewardsBeforeStake == 0, "Rewards are not equal to 0");

        boundStaking.stake(2_000_000e18);
        uint256 balanceAfterStaking = erc20Bound.balanceOf(A);
        assertEq(balanceAfterStaking, 98_000_000e18, "Balance after staking is not 98_000_000e18");

        vm.warp(3154e7);
        uint256 reward = boundStaking.checkRewards(A);
        console.log("reward", reward);

        switchSigner(C);
        wow.approve(address(diamond), 100_000_000e18);
        console.log("Approved");

        switchSigner(A);
        boundStaking.unstake(C, 5_000_000e17);

        uint256 wowBalanceAfterStake = wow.balanceOf(A);
        console.log("wowBalanceAfterStake", wowBalanceAfterStake);
        assertTrue(wowBalanceAfterStake > 0, "WOW balance is not greater than 0");

        uint256 rewardsAfterUnstake = boundStaking.checkRewards(A);
        assertTrue(rewardsAfterUnstake == 0, "Rewards is not equal 0");

        switchSigner(B);

        vm.expectRevert(
            abi.encodeWithSelector(StakingFacet.NoMoney.selector, 0)
        );

        boundStaking.unstake(C, 5_000_000e17);

        bytes32 value = vm.load(
            address(diamond),
            bytes32(abi.encodePacked(uint256(2)))
        );
        uint256 decodevalue = abi.decode(abi.encodePacked(value), (uint256));
        console.log(decodevalue);
    }

    function generateSelectors(
        string memory _facetName
    ) internal returns (bytes4[] memory selectors) {
        string[] memory cmd = new string[](3);
        cmd[0] = "node";
        cmd[1] = "scripts/genSelectors.js";
        cmd[2] = _facetName;
        bytes memory res = vm.ffi(cmd);
        selectors = abi.decode(res, (bytes4[]));
    }

    function mkaddr(string memory name) public returns (address) {
        address addr = address(
            uint160(uint256(keccak256(abi.encodePacked(name))))
        );
        vm.label(addr, name);
        return addr;
    }

    function switchSigner(address _newSigner) public {
        address foundrySigner = 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38;
        if (msg.sender == foundrySigner) {
            vm.startPrank(_newSigner);
        } else {
            vm.stopPrank();
            vm.startPrank(_newSigner);
        }

        // uint256[] memory newArray = new uint256[](2);
    }

    function diamondCut(
        FacetCut[] calldata _diamondCut,
        address _init,
        bytes calldata _calldata
    ) external override {}
}
