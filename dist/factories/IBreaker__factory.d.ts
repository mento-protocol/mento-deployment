import { Signer } from "ethers";
import type { Provider } from "@ethersproject/providers";
import type { IBreaker, IBreakerInterface } from "../IBreaker";
export declare class IBreaker__factory {
    static readonly abi: readonly [{
        readonly anonymous: false;
        readonly inputs: readonly [{
            readonly indexed: false;
            readonly internalType: "address";
            readonly name: "newSortedOracles";
            readonly type: "address";
        }];
        readonly name: "SortedOraclesUpdated";
        readonly type: "event";
    }, {
        readonly constant: true;
        readonly inputs: readonly [{
            readonly internalType: "address";
            readonly name: "rateFeedID";
            readonly type: "address";
        }];
        readonly name: "getCooldown";
        readonly outputs: readonly [{
            readonly internalType: "uint256";
            readonly name: "cooldown";
            readonly type: "uint256";
        }];
        readonly payable: false;
        readonly stateMutability: "view";
        readonly type: "function";
    }, {
        readonly constant: false;
        readonly inputs: readonly [{
            readonly internalType: "address";
            readonly name: "rateFeedID";
            readonly type: "address";
        }];
        readonly name: "shouldReset";
        readonly outputs: readonly [{
            readonly internalType: "bool";
            readonly name: "resetBreaker";
            readonly type: "bool";
        }];
        readonly payable: false;
        readonly stateMutability: "nonpayable";
        readonly type: "function";
    }, {
        readonly constant: false;
        readonly inputs: readonly [{
            readonly internalType: "address";
            readonly name: "rateFeedID";
            readonly type: "address";
        }];
        readonly name: "shouldTrigger";
        readonly outputs: readonly [{
            readonly internalType: "bool";
            readonly name: "triggerBreaker";
            readonly type: "bool";
        }];
        readonly payable: false;
        readonly stateMutability: "nonpayable";
        readonly type: "function";
    }];
    static createInterface(): IBreakerInterface;
    static connect(address: string, signerOrProvider: Signer | Provider): IBreaker;
}
