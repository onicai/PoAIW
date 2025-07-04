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
dfx deploy --network local

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

Update logo:
dfx deploy funnAI_ledger_canister --network development --upgrade-unchanged --argument '(variant {  Upgrade = opt record {    metadata = opt vec {      record { "icrc1:logo"; variant { Text = "data:image/png;base64,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" } }    };  }})'


#############################
Demo Stage:
TOKEN_SYMBOL = FUNNAIdemo
TOKEN_NAME = FUNNAIdemo
MINTER = 4tr6r-mqaaa-aaaae-qfcta-cai // Game State canister demo stage
TRANSFER_FEE = 1 // 1
feature_flags = opt record{icrc2 = true}
DEFAULT_ACCOUNT_ID = 4tr6r-mqaaa-aaaae-qfcta-cai // Game State canister dev stage
PRE_MINTED_TOKENS = 0
NUM_OF_BLOCK_TO_ARCHIVE = 1000000 // 1M
TRIGGER_THRESHOLD = 1000000 // 1M
ARCHIVE_CONTROLLER = 4tr6r-mqaaa-aaaae-qfcta-cai // Game State canister dev stage
cycles_for_archive_creation = 1000000000000 // 1T

"init_arg": "(variant { Init = record { decimals = opt 8; token_symbol = \"FUNNAIdemo\"; token_name = \"FUNNAIdemo\"; transfer_fee = 1; metadata = vec {}; feature_flags = opt record{icrc2 = true}; minting_account = record { owner = principal \"4tr6r-mqaaa-aaaae-qfcta-cai\"; }; initial_balances = vec { record { record { owner = principal \"4tr6r-mqaaa-aaaae-qfcta-cai\"; }; 0; }; };  archive_options = record { num_blocks_to_archive = 1000000; trigger_threshold = 1000000; controller_id = principal \"4tr6r-mqaaa-aaaae-qfcta-cai\"; cycles_for_archive_creation = opt  1000000000000; }; } })"
    

Deploy on demo stage:
dfx deploy funnAI_ledger_canister --network demo

Sanity checks:
dfx canister call funnAI_ledger_canister is_ledger_ready --network demo
dfx canister call funnAI_ledger_canister icrc1_minting_account --network demo
dfx canister call funnAI_ledger_canister icrc1_total_supply --network demo
dfx canister call funnAI_ledger_canister icrc1_supported_standards --network demo
dfx canister call funnAI_ledger_canister icrc10_supported_standards --network demo
dfx canister call funnAI_ledger_canister icrc3_supported_block_types --network demo
dfx canister call funnAI_ledger_canister icrc1_metadata --network demo

TODO (once Game State has token ledger code) Checks on Game State:
dfx canister call game_state_canister --network demo setTokenLedgerCanisterId '("z6s3y-4aaaa-aaaaj-a2bjq-cai")'
 
dfx canister call game_state_canister --network demo testTokenMintingAdmin 

dfx canister call funnAI_ledger_canister icrc1_total_supply --network demo

Update logo:
dfx deploy funnAI_ledger_canister --network demo --upgrade-unchanged --argument '(variant {  Upgrade = opt record {    metadata = opt vec {      record { "icrc1:logo"; variant { Text = "data:image/png;base64,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" } }    };  }})'


######################################
For production:
update minting_account (to production Game State) and other params in init_arg (dfx.json)
recommended settings (as for SNS): https://github.com/dfinity/ic/blob/98fa250f488163fc5d94079c4acd81ba55761bd6/rs/sns/init/src/lib.rs#L600-L613

TOKEN_SYMBOL = FUNNAI
TOKEN_NAME = FUNNAI
MINTER = r5m5y-diaaa-aaaaa-qanaa-cai // Game State canister prd stage
TRANSFER_FEE = 1 // 1
feature_flags = opt record{icrc2 = true}
DEFAULT_ACCOUNT_ID = r5m5y-diaaa-aaaaa-qanaa-cai // Game State canister prd stage
PRE_MINTED_TOKENS = 0
NUM_OF_BLOCK_TO_ARCHIVE = 1000
TRIGGER_THRESHOLD = 2000
ARCHIVE_CONTROLLER = r5m5y-diaaa-aaaaa-qanaa-cai // Game State canister prd stage
cycles_for_archive_creation = 2000000000000 // 2T

for dfx.json:
"init_arg": "(variant { Init = record { decimals = opt 8; token_symbol = \"FUNNAI\"; token_name = \"FUNNAI\"; transfer_fee = 1; metadata = vec {}; feature_flags = opt record{icrc2 = true}; minting_account = record { owner = principal \"r5m5y-diaaa-aaaaa-qanaa-cai\"; }; initial_balances = vec { record { record { owner = principal \"r5m5y-diaaa-aaaaa-qanaa-cai\"; }; 0; }; };  archive_options = record { num_blocks_to_archive = 1000; trigger_threshold = 2000; controller_id = principal \"r5m5y-diaaa-aaaaa-qanaa-cai\"; cycles_for_archive_creation = opt  2000000000000; }; } })"

Deploy on prd stage:
dfx deploy funnAI_ledger_canister --network prd --with-cycles 1000000000000 --next-to r5m5y-diaaa-aaaaa-qanaa-cai

Sanity checks:
dfx canister call funnAI_ledger_canister is_ledger_ready --network prd
dfx canister call funnAI_ledger_canister icrc1_minting_account --network prd
dfx canister call funnAI_ledger_canister icrc1_total_supply --network prd
dfx canister call funnAI_ledger_canister icrc1_supported_standards --network prd
dfx canister call funnAI_ledger_canister icrc10_supported_standards --network prd
dfx canister call funnAI_ledger_canister icrc3_supported_block_types --network prd
dfx canister call funnAI_ledger_canister icrc1_metadata --network prd

On Game State:
dfx canister call game_state_canister --network prd setTokenLedgerCanisterId '("vpyot-zqaaa-aaaaa-qavaq-cai")'
 
dfx canister call game_state_canister --network prd testTokenMintingAdmin 

dfx canister call funnAI_ledger_canister icrc1_total_supply --network prd