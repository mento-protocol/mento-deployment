import { Signer } from "ethers";
import type { Provider } from "@ethersproject/providers";
import type { IBiPoolManager, IBiPoolManagerInterface } from "../IBiPoolManager";
export declare class IBiPoolManager__factory {
    static readonly abi: readonly [{
        readonly anonymous: false;
        readonly inputs: readonly [{
            readonly indexed: false;
            readonly internalType: "address";
            readonly name: "newBreakerBox";
            readonly type: "address";
        }];
        readonly name: "BreakerBoxUpdated";
        readonly type: "event";
    }, {
        readonly anonymous: false;
        readonly inputs: readonly [{
            readonly indexed: true;
            readonly internalType: "address";
            readonly name: "newBroker";
            readonly type: "address";
        }];
        readonly name: "BrokerUpdated";
        readonly type: "event";
    }, {
        readonly anonymous: false;
        readonly inputs: readonly [{
            readonly indexed: true;
            readonly internalType: "bytes32";
            readonly name: "exchangeId";
            readonly type: "bytes32";
        }, {
            readonly indexed: false;
            readonly internalType: "uint256";
            readonly name: "bucket0";
            readonly type: "uint256";
        }, {
            readonly indexed: false;
            readonly internalType: "uint256";
            readonly name: "bucket1";
            readonly type: "uint256";
        }];
        readonly name: "BucketsUpdated";
        readonly type: "event";
    }, {
        readonly anonymous: false;
        readonly inputs: readonly [{
            readonly indexed: true;
            readonly internalType: "bytes32";
            readonly name: "exchangeId";
            readonly type: "bytes32";
        }, {
            readonly indexed: true;
            readonly internalType: "address";
            readonly name: "asset0";
            readonly type: "address";
        }, {
            readonly indexed: true;
            readonly internalType: "address";
            readonly name: "asset1";
            readonly type: "address";
        }, {
            readonly indexed: false;
            readonly internalType: "address";
            readonly name: "pricingModule";
            readonly type: "address";
        }];
        readonly name: "ExchangeCreated";
        readonly type: "event";
    }, {
        readonly anonymous: false;
        readonly inputs: readonly [{
            readonly indexed: true;
            readonly internalType: "bytes32";
            readonly name: "exchangeId";
            readonly type: "bytes32";
        }, {
            readonly indexed: true;
            readonly internalType: "address";
            readonly name: "asset0";
            readonly type: "address";
        }, {
            readonly indexed: true;
            readonly internalType: "address";
            readonly name: "asset1";
            readonly type: "address";
        }, {
            readonly indexed: false;
            readonly internalType: "address";
            readonly name: "pricingModule";
            readonly type: "address";
        }];
        readonly name: "ExchangeDestroyed";
        readonly type: "event";
    }, {
        readonly anonymous: false;
        readonly inputs: readonly [{
            readonly indexed: true;
            readonly internalType: "address";
            readonly name: "newReserve";
            readonly type: "address";
        }];
        readonly name: "ReserveUpdated";
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
        readonly constant: false;
        readonly inputs: readonly [{
            readonly components: readonly [{
                readonly internalType: "address";
                readonly name: "asset0";
                readonly type: "address";
            }, {
                readonly internalType: "address";
                readonly name: "asset1";
                readonly type: "address";
            }, {
                readonly internalType: "contract IPricingModule";
                readonly name: "pricingModule";
                readonly type: "address";
            }, {
                readonly internalType: "uint256";
                readonly name: "bucket0";
                readonly type: "uint256";
            }, {
                readonly internalType: "uint256";
                readonly name: "bucket1";
                readonly type: "uint256";
            }, {
                readonly internalType: "uint256";
                readonly name: "lastBucketUpdate";
                readonly type: "uint256";
            }, {
                readonly components: readonly [{
                    readonly components: readonly [{
                        readonly internalType: "uint256";
                        readonly name: "value";
                        readonly type: "uint256";
                    }];
                    readonly internalType: "struct FixidityLib.Fraction";
                    readonly name: "spread";
                    readonly type: "tuple";
                }, {
                    readonly internalType: "address";
                    readonly name: "referenceRateFeedID";
                    readonly type: "address";
                }, {
                    readonly internalType: "uint256";
                    readonly name: "referenceRateResetFrequency";
                    readonly type: "uint256";
                }, {
                    readonly internalType: "uint256";
                    readonly name: "minimumReports";
                    readonly type: "uint256";
                }, {
                    readonly internalType: "uint256";
                    readonly name: "stablePoolResetSize";
                    readonly type: "uint256";
                }];
                readonly internalType: "struct IBiPoolManager.PoolConfig";
                readonly name: "config";
                readonly type: "tuple";
            }];
            readonly internalType: "struct IBiPoolManager.PoolExchange";
            readonly name: "exchange";
            readonly type: "tuple";
        }];
        readonly name: "createExchange";
        readonly outputs: readonly [{
            readonly internalType: "bytes32";
            readonly name: "exchangeId";
            readonly type: "bytes32";
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
            readonly internalType: "uint256";
            readonly name: "exchangeIdIndex";
            readonly type: "uint256";
        }];
        readonly name: "destroyExchange";
        readonly outputs: readonly [{
            readonly internalType: "bool";
            readonly name: "destroyed";
            readonly type: "bool";
        }];
        readonly payable: false;
        readonly stateMutability: "nonpayable";
        readonly type: "function";
    }, {
        readonly constant: true;
        readonly inputs: readonly [];
        readonly name: "getExchangeIds";
        readonly outputs: readonly [{
            readonly internalType: "bytes32[]";
            readonly name: "exchangeIds";
            readonly type: "bytes32[]";
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
        }];
        readonly name: "getPoolExchange";
        readonly outputs: readonly [{
            readonly components: readonly [{
                readonly internalType: "address";
                readonly name: "asset0";
                readonly type: "address";
            }, {
                readonly internalType: "address";
                readonly name: "asset1";
                readonly type: "address";
            }, {
                readonly internalType: "contract IPricingModule";
                readonly name: "pricingModule";
                readonly type: "address";
            }, {
                readonly internalType: "uint256";
                readonly name: "bucket0";
                readonly type: "uint256";
            }, {
                readonly internalType: "uint256";
                readonly name: "bucket1";
                readonly type: "uint256";
            }, {
                readonly internalType: "uint256";
                readonly name: "lastBucketUpdate";
                readonly type: "uint256";
            }, {
                readonly components: readonly [{
                    readonly components: readonly [{
                        readonly internalType: "uint256";
                        readonly name: "value";
                        readonly type: "uint256";
                    }];
                    readonly internalType: "struct FixidityLib.Fraction";
                    readonly name: "spread";
                    readonly type: "tuple";
                }, {
                    readonly internalType: "address";
                    readonly name: "referenceRateFeedID";
                    readonly type: "address";
                }, {
                    readonly internalType: "uint256";
                    readonly name: "referenceRateResetFrequency";
                    readonly type: "uint256";
                }, {
                    readonly internalType: "uint256";
                    readonly name: "minimumReports";
                    readonly type: "uint256";
                }, {
                    readonly internalType: "uint256";
                    readonly name: "stablePoolResetSize";
                    readonly type: "uint256";
                }];
                readonly internalType: "struct IBiPoolManager.PoolConfig";
                readonly name: "config";
                readonly type: "tuple";
            }];
            readonly internalType: "struct IBiPoolManager.PoolExchange";
            readonly name: "exchange";
            readonly type: "tuple";
        }];
        readonly payable: false;
        readonly stateMutability: "view";
        readonly type: "function";
    }];
    static createInterface(): IBiPoolManagerInterface;
    static connect(address: string, signerOrProvider: Signer | Provider): IBiPoolManager;
}
