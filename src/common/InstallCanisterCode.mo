
import Principal "mo:base/Principal";
import D "mo:base/Debug";
import Blob "mo:base/Blob";
import Iter "mo:base/Iter";
import Sha256 "mo:sha2/Sha256";
import Types "Types";
import Nat "mo:base/Nat";
import Error "mo:base/Error";
import Array "mo:base/Array";
import ICManagementCanister "ICManagementCanister";

module InstallCanisterCode {

    let IC0 : ICManagementCanister.IC_Management = actor ("aaaaa-aa");

    public func installCanisterCode(canisterId: Principal, wasmChunks: [Blob], mode: ICManagementCanister.canister_install_mode) : async Types.Result<(), Text> {
        D.print("installCanisterCode: Start installing code into canister " # Principal.toText(canisterId));

        try {
            var chunkHashesList : [{ hash: Blob }] = [];

            // Upload chunks
            for (chunkIndex in Iter.range(0, wasmChunks.size() - 1)) {
                let chunk = wasmChunks[chunkIndex];
                let result = await IC0.upload_chunk({
                    canister_id = canisterId;
                    chunk = chunk;
                });
                D.print(
                    "installCanisterCode: Uploaded wasm chunk " # Nat.toText(chunkIndex) #
                    " with hash " # debug_show(result.hash)
                );
                chunkHashesList := Array.append(chunkHashesList, [{ hash = result.hash }]);
            };

            // TODO: optimize this by computing it as we upload chunks and then using it here directly
            // Compute SHA256 hash in streaming mode
            let digest = Sha256.Digest(#sha256);
            for (chunk in wasmChunks.vals()) {
                digest.writeBlob(chunk);
            };
            let wasmModuleHash = digest.sum();

            D.print("installCanisterCode: WASM module hash: " # debug_show(wasmModuleHash));

            // Prepare install arguments
            let installArgs = {
                arg = Blob.fromArray([]);
                wasm_module_hash = wasmModuleHash;
                mode = mode;
                chunk_hashes_list = chunkHashesList;
                target_canister = canisterId;
                store_canister = null;
                sender_canister_version = null;
            };

            D.print("installCanisterCode: Calling IC0.install_chunked_code for canister " # Principal.toText(canisterId));

            let _ = await IC0.install_chunked_code(installArgs);

            D.print("installCanisterCode: Successfully installed the WASM module in canister " # Principal.toText(canisterId));

            return #Ok(());
        } catch (e) {
            let errorMsg = "installCanisterCode: Failed installing code into canister " # 
                            Principal.toText(canisterId) # " Error: " # Error.message(e);
            D.print(errorMsg);
            return #Err(errorMsg);
        };
    }
}
