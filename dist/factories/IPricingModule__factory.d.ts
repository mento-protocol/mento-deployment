import { Signer } from "ethers";
import type { Provider } from "@ethersproject/providers";
import type { IPricingModule, IPricingModuleInterface } from "../IPricingModule";
export declare class IPricingModule__factory {
    static readonly abi: readonly [{
        readonly constant: true;
        readonly inputs: readonly [{
            readonly internalType: "uint256";
            readonly name: "tokenInBucketSize";
            readonly type: "uint256";
        }, {
            readonly internalType: "uint256";
            readonly name: "tokenOutBucketSize";
            readonly type: "uint256";
        }, {
            readonly internalType: "uint256";
            readonly name: "spread";
            readonly type: "uint256";
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
            readonly internalType: "uint256";
            readonly name: "tokenInBucketSize";
            readonly type: "uint256";
        }, {
            readonly internalType: "uint256";
            readonly name: "tokenOutBucketSize";
            readonly type: "uint256";
        }, {
            readonly internalType: "uint256";
            readonly name: "spread";
            readonly type: "uint256";
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
        readonly name: "name";
        readonly outputs: readonly [{
            readonly internalType: "string";
            readonly name: "pricingModuleName";
            readonly type: "string";
        }];
        readonly payable: false;
        readonly stateMutability: "view";
        readonly type: "function";
    }];
    static createInterface(): IPricingModuleInterface;
    static connect(address: string, signerOrProvider: Signer | Provider): IPricingModule;
}
