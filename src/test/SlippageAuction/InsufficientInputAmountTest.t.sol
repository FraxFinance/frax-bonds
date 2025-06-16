// SPDX-License-Identifier: ISC
pragma solidity ^0.8.23;

import "../helpers/SwapHelper.sol";

contract InsufficientInputAmountTest is SwapHelper {
    function setUpFraxtal(uint256 _block) public {
        vm.createSelectFork("https://rpc.frax.com", _block);
    }

    function test_InsufficientInputAmount() public {
        setUpFraxtal(10_273_929);
        uint256 amountIn = 10_127_517_341_059_483_017;
        SlippageAuction auction = SlippageAuction(0xfC9f079e9D7Fa6080f61F8541870580Ee7af7CF2);
        console.log("amountIn", amountIn);
        uint256 amountOut = auction.getAmountOut(amountIn, 0xFc00000000000000000000000000000000000001);
        console.log("amountOut", amountOut);
        uint256 amountIn2 = auction.getAmountIn(amountOut, 0xc38173D34afaEA88Bc482813B3CD267bc8A1EA83);
        console.log("amountIn2", amountIn2);

        address whale = 0xaCa39B187352D9805DECEd6E73A3d72ABf86E7A0;
        startHoax(whale);

        IERC20(0xFc00000000000000000000000000000000000001).transfer(address(auction), amountIn);
        bytes memory errorMsg = abi.encodeWithSelector(
            SlippageAuction.InsufficientInputAmount.selector,
            amountIn2,
            amountIn
        );
        vm.expectRevert(errorMsg);
        auction.swap({ amount0Out: 0, amount1Out: amountOut, to: whale, data: new bytes(0) });
    }
}
