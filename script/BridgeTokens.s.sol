//SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {Client} from "@ccip/libraries/Client.sol";
import {IRouterClient} from "@ccip/interfaces/IRouterClient.sol";
import {IERC20} from "@ccip/pools/TokenPool.sol";

contract BridgeTokens is Script {
    function run(
        address receiverAddress,
        uint64 destinationChainSelector,
        address tokenToSendAddress,
        uint256 amountToSend,
        address linkTokenAddress,
        address routerAddress
    ) public {
        Client.EVMTokenAmount[]
            memory tokenAmounts = new Client.EVMTokenAmount[](1);
        tokenAmounts[0] = Client.EVMTokenAmount({
            token: tokenToSendAddress,
            amount: amountToSend
        });

        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(receiverAddress),
            data: "",
            tokenAmounts: tokenAmounts,
            feeToken: linkTokenAddress,
            extraArgs: Client._argsToBytes(Client.EVMExtraArgsV1({gasLimit: 0}))
        });

        vm.startBroadcast();

        uint256 ccipFee = IRouterClient(routerAddress).getFee(
            destinationChainSelector,
            message
        );

        IERC20(linkTokenAddress).approve(routerAddress, ccipFee);
        IERC20(tokenToSendAddress).approve(routerAddress, amountToSend);

        IRouterClient(routerAddress).ccipSend(
            destinationChainSelector,
            message
        );

        vm.stopBroadcast();
    }
}
