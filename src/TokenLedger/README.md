# Token Ledger

Params to specify (see constructor.did):
record {
  decimals = opt 8;
  token_symbol = "FUNNAI"; 
    token_name = "FUNNAI";
  transfer_fee = 1000000 // 1M
  metadata = vec {}; 
  minting_account = record { 
        owner = principal "MINTER";
    };
  initial_balances = vec { record { 
        record { 
            owner = principal "DEFAULT_ACCOUNT_ID"; 
        }; 
        "PRE_MINTED_TOKENS"; 
        };
    }; 
  fee_collector_account : opt Account;
  archive_options : record {
    num_blocks_to_archive = "NUM_OF_BLOCK_TO_ARCHIVE"; 
    trigger_threshold = "TRIGGER_THRESHOLD"; 
    controller_id = principal "ARCHIVE_CONTROLLER"; 
    cycles_for_archive_creation = opt "10000000000000"; 
    
    max_transactions_per_response : opt nat64;
    more_controller_ids : opt vec principal;
    max_message_size_bytes : opt nat64;
    node_max_memory_size_bytes : opt nat64;
  };
  max_memo_length : opt nat16;
  feature_flags = opt record{icrc2 = true}; 
};


Params to specify (see dfx.json):
"init_arg": "(variant 
{
    Init = record { 
        decimals = opt 8;
        token_symbol = "FUNNAI"; 
        token_name = "FUNNAI"; 
        transfer_fee = 1000000;
        metadata = vec {}; 
        feature_flags = opt record{icrc2 = true}; 
        minting_account = record { 
            owner = principal "bkyz2-fmaaa-aaaaa-qaaaq-cai";
        };
        initial_balances = vec { record { 
                record { 
                    owner = principal "bkyz2-fmaaa-aaaaa-qaaaq-cai"; 
                }; 
                0; 
            };
        }; 
        archive_options = record {
            num_blocks_to_archive = 1000000; 
            trigger_threshold = 1000000; 
            controller_id = principal "bkyz2-fmaaa-aaaaa-qaaaq-cai"; 
            cycles_for_archive_creation = opt "10000000000000";
        };
    }
})"

"init_arg": "(variant { Init = record { decimals = opt 8; token_symbol = \"FUNNAI\"; token_name = \"FUNNAI\"; transfer_fee = 1000000; metadata = vec {}; feature_flags = opt record{icrc2 = true}; minting_account = record { owner = principal \"bkyz2-fmaaa-aaaaa-qaaaq-cai\"; }; initial_balances = vec { record { record { owner = principal \"bkyz2-fmaaa-aaaaa-qaaaq-cai\"; }; 0; }; };  archive_options = record { num_blocks_to_archive = 1000000; trigger_threshold = 1000000; controller_id = principal \"bkyz2-fmaaa-aaaaa-qaaaq-cai\"; cycles_for_archive_creation = opt  10000000000000; }; } })"

"init_arg": "(variant { Init = record { decimals = opt 8; token_symbol = \"FUNNAI\"; token_name = \"FUNNAI\"; transfer_fee = 1000000; metadata = vec {}; feature_flags = opt record{icrc2 = true}; minting_account = record { owner = principal \"bkyz2-fmaaa-aaaaa-qaaaq-cai\"; }; initial_balances = vec { record { record { owner = principal \"bkyz2-fmaaa-aaaaa-qaaaq-cai\"; }; 0; }; };  archive_options = record { num_blocks_to_archive = 1000000; trigger_threshold = 1000000; controller_id = principal \"bkyz2-fmaaa-aaaaa-qaaaq-cai\"; cycles_for_archive_creation = opt  10000000000000; }; } })"

TOKEN_SYMBOL = FUNNAI
TOKEN_NAME = FUNNAI
MINTER = bkyz2-fmaaa-aaaaa-qaaaq-cai // Game State canister
TRANSFER_FEE = 1000000 // 1M
feature_flags = opt record{icrc2 = true}
DEFAULT_ACCOUNT_ID = bkyz2-fmaaa-aaaaa-qaaaq-cai // Game State canister
PRE_MINTED_TOKENS = 0
NUM_OF_BLOCK_TO_ARCHIVE = 1000000 // 1M
TRIGGER_THRESHOLD = 1000000 // 1M
ARCHIVE_CONTROLLER = bkyz2-fmaaa-aaaaa-qaaaq-cai // Game State canister
cycles_for_archive_creation = 10000000000000 // 10T

Deploy:
dfx deploy

Sanity checks:
dfx canister call funnAI_ledger_canister is_ledger_ready
dfx canister call funnAI_ledger_canister icrc1_minting_account
dfx canister call funnAI_ledger_canister icrc1_total_supply

Checks on Game State:
dfx canister call game_state_canister --network local setTokenLedgerCanisterId '("cinef-v4aaa-aaaaa-qaalq-cai")'
 
dfx canister call game_state_canister --network local testTokenMintingAdmin 

dfx canister call funnAI_ledger_canister icrc1_total_supply

#############################
Development Stage:
TOKEN_SYMBOL = FUNNAIdev
TOKEN_NAME = FUNNAIdev
MINTER = ciqqv-4iaaa-aaaag-auara-cai // Game State canister dev stage
TRANSFER_FEE = 1 // 1
feature_flags = opt record{icrc2 = true}
DEFAULT_ACCOUNT_ID = ciqqv-4iaaa-aaaag-auara-cai // Game State canister dev stage
PRE_MINTED_TOKENS = 0
NUM_OF_BLOCK_TO_ARCHIVE = 1000000 // 1M
TRIGGER_THRESHOLD = 1000000 // 1M
ARCHIVE_CONTROLLER = ciqqv-4iaaa-aaaag-auara-cai // Game State canister dev stage
cycles_for_archive_creation = 1000000000000 // 1T

"init_arg": "(variant { Init = record { decimals = opt 8; token_symbol = \"FUNNAIdev\"; token_name = \"FUNNAIdev\"; transfer_fee = 1; metadata = vec {}; feature_flags = opt record{icrc2 = true}; minting_account = record { owner = principal \"ciqqv-4iaaa-aaaag-auara-cai\"; }; initial_balances = vec { record { record { owner = principal \"ciqqv-4iaaa-aaaag-auara-cai\"; }; 0; }; };  archive_options = record { num_blocks_to_archive = 1000000; trigger_threshold = 1000000; controller_id = principal \"ciqqv-4iaaa-aaaag-auara-cai\"; cycles_for_archive_creation = opt  1000000000000; }; } })"
    

Deploy on dev stage:
dfx deploy funnAI_ledger_canister --network development

Sanity checks:
dfx canister call funnAI_ledger_canister is_ledger_ready --network development
dfx canister call funnAI_ledger_canister icrc1_minting_account --network development
dfx canister call funnAI_ledger_canister icrc1_total_supply --network development

TODO (once Game State has token ledger code) Checks on Game State:
dfx canister call game_state_canister --network development setTokenLedgerCanisterId '("4uuff-dyaaa-aaaaj-qnoeq-cai")'
 
dfx canister call game_state_canister --network development testTokenMintingAdmin 

dfx canister call funnAI_ledger_canister icrc1_total_supply --network development



######################################
For production:
update minting_account (to production Game State) and other params in init_arg (dfx.json)