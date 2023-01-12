import type { BaseContract, BigNumber, BytesLike, CallOverrides, ContractTransaction, Overrides, PopulatedTransaction, Signer, utils } from "ethers";
import type { FunctionFragment, Result, EventFragment } from "@ethersproject/abi";
import type { Listener, Provider } from "@ethersproject/providers";
import type { TypedEventFilter, TypedEvent, TypedListener, OnEvent, PromiseOrValue } from "./common";
export interface IBreakerInterface extends utils.Interface {
    functions: {
        "getCooldown(address)": FunctionFragment;
        "shouldReset(address)": FunctionFragment;
        "shouldTrigger(address)": FunctionFragment;
    };
    getFunction(nameOrSignatureOrTopic: "getCooldown" | "shouldReset" | "shouldTrigger"): FunctionFragment;
    encodeFunctionData(functionFragment: "getCooldown", values: [PromiseOrValue<string>]): string;
    encodeFunctionData(functionFragment: "shouldReset", values: [PromiseOrValue<string>]): string;
    encodeFunctionData(functionFragment: "shouldTrigger", values: [PromiseOrValue<string>]): string;
    decodeFunctionResult(functionFragment: "getCooldown", data: BytesLike): Result;
    decodeFunctionResult(functionFragment: "shouldReset", data: BytesLike): Result;
    decodeFunctionResult(functionFragment: "shouldTrigger", data: BytesLike): Result;
    events: {
        "SortedOraclesUpdated(address)": EventFragment;
    };
    getEvent(nameOrSignatureOrTopic: "SortedOraclesUpdated"): EventFragment;
}
export interface SortedOraclesUpdatedEventObject {
    newSortedOracles: string;
}
export type SortedOraclesUpdatedEvent = TypedEvent<[
    string
], SortedOraclesUpdatedEventObject>;
export type SortedOraclesUpdatedEventFilter = TypedEventFilter<SortedOraclesUpdatedEvent>;
export interface IBreaker extends BaseContract {
    connect(signerOrProvider: Signer | Provider | string): this;
    attach(addressOrName: string): this;
    deployed(): Promise<this>;
    interface: IBreakerInterface;
    queryFilter<TEvent extends TypedEvent>(event: TypedEventFilter<TEvent>, fromBlockOrBlockhash?: string | number | undefined, toBlock?: string | number | undefined): Promise<Array<TEvent>>;
    listeners<TEvent extends TypedEvent>(eventFilter?: TypedEventFilter<TEvent>): Array<TypedListener<TEvent>>;
    listeners(eventName?: string): Array<Listener>;
    removeAllListeners<TEvent extends TypedEvent>(eventFilter: TypedEventFilter<TEvent>): this;
    removeAllListeners(eventName?: string): this;
    off: OnEvent<this>;
    on: OnEvent<this>;
    once: OnEvent<this>;
    removeListener: OnEvent<this>;
    functions: {
        getCooldown(rateFeedID: PromiseOrValue<string>, overrides?: CallOverrides): Promise<[BigNumber] & {
            cooldown: BigNumber;
        }>;
        shouldReset(rateFeedID: PromiseOrValue<string>, overrides?: Overrides & {
            from?: PromiseOrValue<string>;
        }): Promise<ContractTransaction>;
        shouldTrigger(rateFeedID: PromiseOrValue<string>, overrides?: Overrides & {
            from?: PromiseOrValue<string>;
        }): Promise<ContractTransaction>;
    };
    getCooldown(rateFeedID: PromiseOrValue<string>, overrides?: CallOverrides): Promise<BigNumber>;
    shouldReset(rateFeedID: PromiseOrValue<string>, overrides?: Overrides & {
        from?: PromiseOrValue<string>;
    }): Promise<ContractTransaction>;
    shouldTrigger(rateFeedID: PromiseOrValue<string>, overrides?: Overrides & {
        from?: PromiseOrValue<string>;
    }): Promise<ContractTransaction>;
    callStatic: {
        getCooldown(rateFeedID: PromiseOrValue<string>, overrides?: CallOverrides): Promise<BigNumber>;
        shouldReset(rateFeedID: PromiseOrValue<string>, overrides?: CallOverrides): Promise<boolean>;
        shouldTrigger(rateFeedID: PromiseOrValue<string>, overrides?: CallOverrides): Promise<boolean>;
    };
    filters: {
        "SortedOraclesUpdated(address)"(newSortedOracles?: null): SortedOraclesUpdatedEventFilter;
        SortedOraclesUpdated(newSortedOracles?: null): SortedOraclesUpdatedEventFilter;
    };
    estimateGas: {
        getCooldown(rateFeedID: PromiseOrValue<string>, overrides?: CallOverrides): Promise<BigNumber>;
        shouldReset(rateFeedID: PromiseOrValue<string>, overrides?: Overrides & {
            from?: PromiseOrValue<string>;
        }): Promise<BigNumber>;
        shouldTrigger(rateFeedID: PromiseOrValue<string>, overrides?: Overrides & {
            from?: PromiseOrValue<string>;
        }): Promise<BigNumber>;
    };
    populateTransaction: {
        getCooldown(rateFeedID: PromiseOrValue<string>, overrides?: CallOverrides): Promise<PopulatedTransaction>;
        shouldReset(rateFeedID: PromiseOrValue<string>, overrides?: Overrides & {
            from?: PromiseOrValue<string>;
        }): Promise<PopulatedTransaction>;
        shouldTrigger(rateFeedID: PromiseOrValue<string>, overrides?: Overrides & {
            from?: PromiseOrValue<string>;
        }): Promise<PopulatedTransaction>;
    };
}
