# Token Ledger

Params to specify (see dfx.json):
"init_arg": "(variant 
{
    Init = record { 
        token_symbol = "TOKEN_SYMBOL"; 
        token_name = "TOKEN_NAME"; 
        minting_account = record { 
            owner = principal "MINTER"; 
            transfer_fee = TRANSFER_FEE; 
            metadata = vec {}; 
            feature_flags = opt record{icrc2 = false}; 
            initial_balances = vec { record { 
                record { 
                    owner = principal "DEFAULT_ACCOUNT_ID"; 
                }; 
                "PRE_MINTED_TOKENS"; 
                };
            }; 
            archive_options = record { 
                num_blocks_to_archive = "NUM_OF_BLOCK_TO_ARCHIVE"; 
                trigger_threshold = "TRIGGER_THRESHOLD"; 
                controller_id = principal "ARCHIVE_CONTROLLER"; 
                cycles_for_archive_creation = opt "10000000000000"; 
            };
        }}
})"

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