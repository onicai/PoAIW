import Array "mo:base/Array";
import Principal "mo:base/Principal";
import Cycles "mo:base/ExperimentalCycles";
import D "mo:base/Debug";

import Types "Types";
import CMC "cycles-minting-canister-interface";

// Actor with functions to create a canister via the cycles minting canister interface.

module CreateCanisterWithCMC {
    // In the calling canister (e.g., MainerCreator)
    let CMC_ACTOR : CMC.CYCLES_MINTING_CANISTER = Types.CyclesMintingCanister_Actor;

    /// Create a canister on a specific subnet.
    public func createCanisterOnSubnet(cycles_to_attach: Nat, subnet: Text, controllers: ?[Principal]) : async {
        #Ok : Principal;
        #Err : Text;
    } {
        if (cycles_to_attach < 100_000_000_000) {
        D.print("CreateCanisterWithCMC: createCanisterOnSubnet - Insufficient cycles provided. Must be at least 100 billion cycles.");
        return #Err "Insufficient cycles for canister creation.";
        };

        let canisterSettings : CMC.CanisterSettings = {
            freezing_threshold = null;
            wasm_memory_threshold = null;
            controllers = controllers;
            reserved_cycles_limit = null;
            log_visibility = null;
            wasm_memory_limit = null;
            memory_allocation = null;
            compute_allocation = null;
        };

        let createCanisterArg : CMC.CreateCanisterArg = {
            subnet_selection = ?#Subnet { subnet = Principal.fromText(subnet) };
            settings = ?canisterSettings;
            subnet_type = null; // subnet_type is null when subnet_selection is used with #Subnet
        };

        D.print("CreateCanisterWithCMC: createCanisterOnSubnet - calling Cycles.add for = " # debug_show(cycles_to_attach) # " Cycles");
        Cycles.add<system>(cycles_to_attach);

        D.print("CreateCanisterWithCMC: createCanisterOnSubnet - Calling CMC.create_canister targeting subnet " # subnet );
        let createCanisterResult = await CMC_ACTOR.create_canister(createCanisterArg);

        switch (createCanisterResult) {
            case (#Ok(new_canister_id)) {
                D.print("CreateCanisterWithCMC: createCanisterOnSubnet - Canister created successfully. New Canister ID: " # Principal.toText(new_canister_id));
                return #Ok new_canister_id;
            };
            case (#Err(error_variant)) {
                switch (error_variant) {
                case (#Refunded(refund_info)) {
                    D.print(
                    "CreateCanisterWithCMC: createCanisterOnSubnet - Canister creation failed - cycles refunded. Reason: "
                    # refund_info.create_error
                    # " (Refunded cycles: " # debug_show(refund_info.refund_amount) # ")"
                    );
                    return #Err ("Refunded: " # refund_info.create_error);
                };
                };
            };
        };
    };

    /// Fetch available subnets and their types.
    public func getDefaultSubnets() : async [Principal] {
        let subnets = await CMC_ACTOR.get_default_subnets();
        return subnets;
    };

    /// Check if a given subnet ID exists in available subnets.
    public func isSubnetAvailable(subnet: Text) : async Bool {
        let subnets = await getDefaultSubnets();
        if (Array.find<Principal>(subnets, func (s) = (s == Principal.fromText(subnet))) != null) {
            D.print("CreateCanisterWithCMC: isSubnetAvailable - Subnet " # subnet # " found in Default Subnets: ");
            return true;
        };
        D.print("CreateCanisterWithCMC: isSubnetAvailable - Subnet " # subnet # " NOT found in available subnets." # debug_show(subnets));
        return false;
    };
};