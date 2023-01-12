import { Signer } from "ethers";
import type { Provider } from "@ethersproject/providers";
import type { IBroker, IBrokerInterface } from "../IBroker";
export declare class IBroker__factory {
    static readonly abi: readonly [{
        readonly anonymous: false;
        readonly inputs: readonly [{
            readonly indexed: false;
            readonly internalType: "address";
            readonly name: "exchangeProvider";
            readonly type: "address";
        }, {
            readonly indexed: true;
            readonly internalType: "bytes32";
            readonly name: "exchangeId";
            readonly type: "bytes32";
        }, {
            readonly indexed: true;
            readonly internalType: "address";
            readonly name: "trader";
            readonly type: "address";
        }, {
            readonly indexed: true;
            readonly internalType: "address";
            readonly name: "tokenIn";
            readonly type: "address";
        }, {
            readonly indexed: false;
            readonly internalType: "address";
            readonly name: "tokenOut";
            readonly type: "address";
        }, {
            readonly indexed: false;
            readonly internalType: "uint256";
            readonly name: "amountIn";
            readonly type: "uint256";
        }, {
            readonly indexed: false;
            readonly internalType: "uint256";
            readonly name: "amountOut";
            readonly type: "uint256";
        }];
        readonly name: "Swap";
        readonly type: "event";
    }, {
        readonly constant: true;
        readonly inputs: readonly [{
            readonly internalType: "address";
            readonly name: "exchangeProvider";
            readonly type: "address";
        }, {
            readonly internalType: "bytes32";
            readonly name: "exchangeId";
            readonly type: "bytes32";
        }, {
            readonly internalType: "address";
            readonly name: "tokenIn";
            readonly type: "address";
        }, {
            readonly internalType: "address";
            readonly name: "tokenOut";
            readonly type: "address";
        }, {
            readonly internalType: "uint256";
            readonly name: "amountOut";
            readonly type: "uint256";
        }];
        readonly name: "getAmountIn";
        readonly outputs: readonly [{
            readonly internalType: "uint256";
            readonly name: "amountIn";
            readonly type: "uint256";
        }];
        readonly payable: false;
        readonly stateMutability: "view";
        readonly type: "function";
    }, {
        readonly constant: true;
        readonly inputs: readonly [{
            readonly internalType: "address";
            readonly name: "exchangeProvider";
            readonly type: "address";
        }, {
            readonly internalType: "bytes32";
            readonly name: "exchangeId";
            readonly type: "bytes32";
        }, {
            readonly internalType: "address";
            readonly name: "tokenIn";
            readonly type: "address";
        }, {
            readonly internalType: "address";
            readonly name: "tokenOut";
            readonly type: "address";
        }, {
            readonly internalType: "uint256";
            readonly name: "amountIn";
            readonly type: "uint256";
        }];
        readonly name: "getAmountOut";
        readonly outputs: readonly [{
            readonly internalType: "uint256";
            readonly name: "amountOut";
            readonly type: "uint256";
        }];
        readonly payable: false;
        readonly stateMutability: "view";
        readonly type: "function";
    }, {
        readonly constant: true;
        readonly inputs: readonly [];
        readonly name: "getExchangeProviders";
        readonly outputs: readonly [{
            readonly internalType: "address[]";
            readonly name: "exchangeProviders";
            readonly type: "address[]";
        }];
        readonly payable: false;
        readonly stateMutability: "view";
        readonly type: "function";
    }, {
        readonly constant: false;
        readonly inputs: readonly [{
            readonly internalType: "address";
            readonly name: "exchangeProvider";
            readonly type: "address";
        }, {
            readonly internalType: "bytes32";
            readonly name: "exchangeId";
            readonly type: "bytes32";
        }, {
            readonly internalType: "address";
            readonly name: "tokenIn";
            readonly type: "address";
        }, {
            readonly internalType: "address";
            readonly name: "tokenOut";
            readonly type: "address";
        }, {
            readonly internalType: "uint256";
            readonly name: "amountIn";
            readonly type: "uint256";
        }, {
            readonly internalType: "uint256";
            readonly name: "amountOutMin";
            readonly type: "uint256";
        }];
        readonly name: "swapIn";
        readonly outputs: readonly [{
            readonly internalType: "uint256";
            readonly name: "amountOut";
            readonly type: "uint256";
        }];
        readonly payable: false;
        readonly stateMutability: "nonpayable";
        readonly type: "function";
    }, {
        readonly constant: false;
        readonly inputs: readonly [{
            readonly internalType: "address";
            readonly name: "exchangeProvider";
            readonly type: "address";
        }, {
            readonly internalType: "bytes32";
            readonly name: "exchangeId";
            readonly type: "bytes32";
        }, {
            readonly internalType: "address";
            readonly name: "tokenIn";
            readonly type: "address";
        }, {
            readonly internalType: "address";
            readonly name: "tokenOut";
            readonly type: "address";
        }, {
            readonly internalType: "uint256";
            readonly name: "amountOut";
            readonly type: "uint256";
        }, {
            readonly internalType: "uint256";
            readonly name: "amountInMax";
            readonly type: "uint256";
        }];
        readonly name: "swapOut";
        readonly outputs: readonly [{
            readonly internalType: "uint256";
            readonly name: "amountIn";
            readonly type: "uint256";
        }];
        readonly payable: false;
        readonly stateMutability: "nonpayable";
        readonly type: "function";
    }];
    static createInterface(): IBrokerInterface;
    static connect(address: string, signerOrProvider: Signer | Provider): IBroker;
}
