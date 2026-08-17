#!/usr/bin/env python3
"""
Send 0.1 ICP from the `topup-tester` identity to GameState's ledger account
with an ICRC-1 memo blob that binds the payment to a given target mAIner.

Why this script exists (instead of `icp` CLI transfers or `icp canister call
... icrc1_transfer ...`):
  - `dfx ledger transfer` (legacy) only accepts an 8-byte `--memo <Nat64>`,
    so it can't carry the 11-byte bound memo at all.
  - `dfx 0.29.x canister call ... icrc1_transfer "(record { ... memo = opt
    blob \"\\AD\\00...\"; ... })"` mis-parses the blob hex-escapes — an 11-byte
    memo (1 marker + 10 principal bytes) is inflated past the ICP ledger's
    32-byte MEMO_SIZE_BYTES limit and traps with `the memo field is too large`.
  - `icp-py-core` encodes the memo blob correctly. Verified end-to-end: the
    same 11-byte memo sent here is accepted by the ledger.

The redeem step (`icp canister call <GameState> topUpCyclesForAnyMainerAgent
...`) does not have the blob-escape issue and remains a plain CLI call.

Usage:
    python3 pay_topup.py <target_mainer_canister_id> <gamestate_canister_id>

Prereqs:
  - `pip install icp-py-core` in the active env (the `llama_cpp_canister`
    conda env already has it).
  - `icp identity export topup-tester > /tmp/topup-tester.pem`  (icp-cli; dfx is deprecated)
    (one-time, decrypts the keyring-stored PEM).

On success, prints the ICP-ledger block index on stdout (capture-friendly):
    BLOCK=$(python3 pay_topup.py "$TARGET_MAINER" "$SUBNET_0_1_GAMESTATE")
"""

import os
import sys

from icp_agent import Agent, Client
from icp_canister import Canister
from icp_identity import Identity
from icp_principal import Principal

MEMO_PAYMENT_MARKER = 0xAD
ICP_LEDGER_CANISTER_ID = "ryjl3-tyaaa-aaaaa-aaaba-cai"
TOPUP_TESTER_PEM = os.path.expanduser(
    "~/.config/icp/identity/topup-tester/identity.pem"
)
AMOUNT_E8S = 10_000_000  # 0.1 ICP
FEE_E8S = 10_000

LEDGER_DID = """
type Account = record { owner : principal; subaccount : opt blob };
type TransferArg = record {
  from_subaccount : opt blob;
  to : Account;
  amount : nat;
  fee : opt nat;
  memo : opt blob;
  created_at_time : opt nat64;
};
type TransferError = variant {
  BadFee : record { expected_fee : nat };
  BadBurn : record { min_burn_amount : nat };
  InsufficientFunds : record { balance : nat };
  TooOld;
  CreatedInFuture : record { ledger_time : nat64 };
  Duplicate : record { duplicate_of : nat };
  TemporarilyUnavailable;
  GenericError : record { error_code : nat; message : text };
};
type Result = variant { Ok : nat; Err : TransferError };
service : { icrc1_transfer : (TransferArg) -> (Result); }
"""


def main() -> int:
    if len(sys.argv) != 3:
        print(
            "usage: pay_topup.py <target_mainer_canister_id> <gamestate_canister_id>",
            file=sys.stderr,
        )
        return 2

    target_mainer = sys.argv[1]
    gamestate = sys.argv[2]

    if not os.path.exists(TOPUP_TESTER_PEM):
        print(
            f"ERROR: no plaintext PEM at {TOPUP_TESTER_PEM}.\n"
            f"Run: icp identity export topup-tester > {TOPUP_TESTER_PEM}",
            file=sys.stderr,
        )
        return 1

    with open(TOPUP_TESTER_PEM) as f:
        identity = Identity.from_pem(f.read())
    agent = Agent(identity, Client(url="https://ic0.app"))
    ledger = Canister(agent, ICP_LEDGER_CANISTER_ID, LEDGER_DID)

    target = Principal.from_str(target_mainer)
    memo = bytes([MEMO_PAYMENT_MARKER]) + target.bytes

    result = ledger.icrc1_transfer(
        {
            "from_subaccount": None,
            "to": {"owner": Principal.from_str(gamestate), "subaccount": None},
            "amount": AMOUNT_E8S,
            "fee": [FEE_E8S],
            "memo": [memo],
            "created_at_time": None,
        },
        verify_certificate=False,
    )

    value = result[0]["value"]
    if "Ok" in value:
        print(value["Ok"])
        return 0

    print(f"icrc1_transfer FAILED: {value['Err']}", file=sys.stderr)
    return 1


if __name__ == "__main__":
    sys.exit(main())
