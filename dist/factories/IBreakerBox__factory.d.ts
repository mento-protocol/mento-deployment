import { Signer } from "ethers";
import type { Provider } from "@ethersproject/providers";
import type { IBreakerBox, IBreakerBoxInterface } from "../IBreakerBox";
export declare class IBreakerBox__factory {
    static readonly abi: readonly [{
        readonly anonymous: false;
        readonly inputs: readonly [{
            readonly indexed: true;
            readonly internalType: "address";
            readonly name: "breaker";
            readonly type: "address";
        }];
        readonly name: "BreakerAdded";
        readonly type: "event";
    }, {
        readonly anonymous: false;
        readonly inputs: readonly [{
            readonly indexed: true;
            readonly internalType: "address";
            readonly name: "breaker";
            readonly type: "address";
        }];
        readonly name: "BreakerRemoved";
        readonly type: "event";
    }, {
        readonly anonymous: false;
        readonly inputs: readonly [{
            readonly indexed: false;
            readonly internalType: "address";
            readonly name: "breaker";
            readonly type: "address";
        }, {
            readonly indexed: false;
            readonly internalType: "address";
            readonly name: "rateFeedID";
            readonly type: "address";
        }, {
            readonly indexed: false;
            readonly internalType: "bool";
            readonly name: "status";
            readonly type: "bool";
        }];
        readonly name: "BreakerStatusUpdated";
        readonly type: "event";
    }, {
        readonly anonymous: false;
        readonly inputs: readonly [{
            readonly indexed: true;
            readonly internalType: "address";
            readonly name: "breaker";
            readonly type: "address";
        }, {
            readonly indexed: true;
            readonly internalType: "address";
            readonly name: "rateFeedID";
            readonly type: "address";
        }];
        readonly name: "BreakerTripped";
        readonly type: "event";
    }, {
        readonly anonymous: false;
        readonly inputs: readonly [{
            readonly indexed: true;
            readonly internalType: "address";
            readonly name: "rateFeedID";
            readonly type: "address";
        }];
        readonly name: "RateFeedAdded";
        readonly type: "event";
    }, {
        readonly anonymous: false;
        readonly inputs: readonly [{
            readonly indexed: true;
            readonly internalType: "address";
            readonly name: "rateFeedID";
            readonly type: "address";
        }];
        readonly name: "RateFeedRemoved";
        readonly type: "event";
    }, {
        readonly anonymous: false;
        readonly inputs: readonly [{
            readonly indexed: true;
            readonly internalType: "address";
            readonly name: "rateFeedID";
            readonly type: "address";
        }, {
            readonly indexed: true;
            readonly internalType: "address";
            readonly name: "breaker";
            readonly type: "address";
        }];
        readonly name: "ResetAttemptCriteriaFail";
        readonly type: "event";
    }, {
        readonly anonymous: false;
        readonly inputs: readonly [{
            readonly indexed: true;
            readonly internalType: "address";
            readonly name: "rateFeedID";
            readonly type: "address";
        }, {
            readonly indexed: true;
            readonly internalType: "address";
            readonly name: "breaker";
            readonly type: "address";
        }];
        readonly name: "ResetAttemptNotCool";
        readonly type: "event";
    }, {
        readonly anonymous: false;
        readonly inputs: readonly [{
            readonly indexed: true;
            readonly internalType: "address";
            readonly name: "rateFeedID";
            readonly type: "address";
        }, {
            readonly indexed: true;
            readonly internalType: "address";
            readonly name: "breaker";
            readonly type: "address";
        }];
        readonly name: "ResetSuccessful";
        readonly type: "event";
    }, {
        readonly anonymous: false;
        readonly inputs: readonly [{
            readonly indexed: true;
            readonly internalType: "address";
            readonly name: "newSortedOracles";
            readonly type: "address";
        }];
        readonly name: "SortedOraclesUpdated";
        readonly type: "event";
    }, {
        readonly anonymous: false;
        readonly inputs: readonly [{
            readonly indexed: true;
            readonly internalType: "address";
            readonly name: "rateFeedID";
            readonly type: "address";
        }, {
            readonly indexed: false;
            readonly internalType: "uint256";
            readonly name: "tradingMode";
            readonly type: "uint256";
        }];
        readonly name: "TradingModeUpdated";
        readonly type: "event";
    }, {
        readonly constant: false;
        readonly inputs: readonly [{
            readonly internalType: "address";
            readonly name: "rateFeedID";
            readonly type: "address";
        }];
        readonly name: "checkAndSetBreakers";
        readonly outputs: readonly [];
        readonly payable: false;
        readonly stateMutability: "nonpayable";
        readonly type: "function";
    }, {
        readonly constant: true;
        readonly inputs: readonly [];
        readonly name: "getBreakers";
        readonly outputs: readonly [{
            readonly internalType: "address[]";
            readonly name: "";
            readonly type: "address[]";
        }];
        readonly payable: false;
        readonly stateMutability: "view";
        readonly type: "function";
    }, {
        readonly constant: true;
        readonly inputs: readonly [{
            readonly internalType: "address";
            readonly name: "rateFeedID";
            readonly type: "address";
        }];
        readonly name: "getRateFeedTradingMode";
        readonly outputs: readonly [{
            readonly internalType: "uint256";
            readonly name: "tradingMode";
            readonly type: "uint256";
        }];
        readonly payable: false;
        readonly stateMutability: "view";
        readonly type: "function";
    }, {
        readonly constant: true;
        readonly inputs: readonly [{
            readonly internalType: "address";
            readonly name: "breaker";
            readonly type: "address";
        }];
        readonly name: "isBreaker";
        readonly outputs: readonly [{
            readonly internalType: "bool";
            readonly name: "";
            readonly type: "bool";
        }];
        readonly payable: false;
        readonly stateMutability: "view";
        readonly type: "function";
    }];
    static createInterface(): IBreakerBoxInterface;
    static connect(address: string, signerOrProvider: Signer | Provider): IBreakerBox;
}
