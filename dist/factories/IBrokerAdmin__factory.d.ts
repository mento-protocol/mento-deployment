import { Signer } from "ethers";
import type { Provider } from "@ethersproject/providers";
import type { IBrokerAdmin, IBrokerAdminInterface } from "../IBrokerAdmin";
export declare class IBrokerAdmin__factory {
    static readonly abi: readonly [{
        readonly anonymous: false;
        readonly inputs: readonly [{
            readonly indexed: true;
            readonly internalType: "address";
            readonly name: "exchangeProvider";
            readonly type: "address";
        }];
        readonly name: "ExchangeProviderAdded";
        readonly type: "event";
    }, {
        readonly anonymous: false;
        readonly inputs: readonly [{
            readonly indexed: true;
            readonly internalType: "address";
            readonly name: "exchangeProvider";
            readonly type: "address";
        }];
        readonly name: "ExchangeProviderRemoved";
        readonly type: "event";
    }, {
        readonly anonymous: false;
        readonly inputs: readonly [{
            readonly indexed: true;
            readonly internalType: "address";
            readonly name: "newAddress";
            readonly type: "address";
        }, {
            readonly indexed: true;
            readonly internalType: "address";
            readonly name: "prevAddress";
            readonly type: "address";
        }];
        readonly name: "ReserveSet";
        readonly type: "event";
    }, {
        readonly constant: false;
        readonly inputs: readonly [{
            readonly internalType: "address";
            readonly name: "exchangeProvider";
            readonly type: "address";
        }];
        readonly name: "addExchangeProvider";
        readonly outputs: readonly [{
            readonly internalType: "uint256";
            readonly name: "index";
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
            readonly internalType: "uint256";
            readonly name: "index";
            readonly type: "uint256";
        }];
        readonly name: "removeExchangeProvider";
        readonly outputs: readonly [];
        readonly payable: false;
        readonly stateMutability: "nonpayable";
        readonly type: "function";
    }, {
        readonly constant: false;
        readonly inputs: readonly [{
            readonly internalType: "address";
            readonly name: "reserve";
            readonly type: "address";
        }];
        readonly name: "setReserve";
        readonly outputs: readonly [];
        readonly payable: false;
        readonly stateMutability: "nonpayable";
        readonly type: "function";
    }];
    static createInterface(): IBrokerAdminInterface;
    static connect(address: string, signerOrProvider: Signer | Provider): IBrokerAdmin;
}
