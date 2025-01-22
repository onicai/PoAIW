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