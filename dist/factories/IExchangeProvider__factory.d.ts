import { Signer } from "ethers";
import type { Provider } from "@ethersproject/providers";
import type { IExchangeProvider, IExchangeProviderInterface } from "../IExchangeProvider";
export declare class IExchangeProvider__factory {
    static readonly abi: readonly [{
        readonly constant: true;
        readonly inputs: readonly [{
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
        readonly name: "getExchanges";
        readonly outputs: readonly [{
            readonly components: readonly [{
                readonly internalType: "bytes32";
                readonly name: "exchangeId";
                readonly type: "bytes32";
            }, {
                readonly internalType: "address[]";
                readonly name: "assets";
                readonly type: "address[]";
            }];
            readonly internalType: "struct IExchangeProvider.Exchange[]";
            readonly name: "exchanges";
            readonly type: "tuple[]";
        }];
        readonly payable: false;
        readonly stateMutability: "view";
        readonly type: "function";
    }, {
        readonly constant: false;
        readonly inputs: readonly [{
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
    static createInterface(): IExchangeProviderInterface;
    static connect(address: string, signerOrProvider: Signer | Provider): IExchangeProvider;
}
