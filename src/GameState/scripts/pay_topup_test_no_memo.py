#!/usr/bin/env python3
"""
Test-only variant of pay_topup.py: send 0.1 ICP from `topup-tester` to
GameState's ledger account with NO memo (no bound memo, no legacy memo).

This is used by Scenario 6 in PoAIW/src/GameState/README.md to exercise the
"missing or invalid memo" rejection path on `topUpCyclesForAnyMainerAgent`.
For all other scenarios, use pay_topup.py instead.

Usage:
    python3 pay_topup_test_no_memo.py <gamestate_canister_id>

Prereqs (same as pay_topup.py):
  - `pip install icp-py-core` in the active env (the `llama_cpp_canister`
    conda env already has it).
  - `dfx identity export topup-tester > ~/.config/dfx/identity/topup-tester/identity.pem`

On success, prints the ICP-ledger block index on stdout.
"""

import os
import sys

from icp_agent import Agent, Client
from icp_canister import Canister
from icp_identity import Identity
from icp_principal import Principal

ICP_LEDGER_CANISTER_ID = "ryjl3-tyaaa-aaaaa-aaaba-cai"
TOPUP_TESTER_PEM = os.path.expanduser(
    "~/.config/dfx/identity/topup-tester/identity.pem"
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
    if len(sys.argv) != 2:
        print(
            "usage: pay_topup_test_no_memo.py <gamestate_canister_id>",
            file=sys.stderr,
        )
        return 2

    gamestate = sys.argv[1]

    if not os.path.exists(TOPUP_TESTER_PEM):
        print(
            f"ERROR: no plaintext PEM at {TOPUP_TESTER_PEM}.\n"
            f"Run: dfx identity export topup-tester > {TOPUP_TESTER_PEM}",
            file=sys.stderr,
        )
        return 1

    with open(TOPUP_TESTER_PEM) as f:
        identity = Identity.from_pem(f.read())
    agent = Agent(identity, Client(url="https://ic0.app"))
    ledger = Canister(agent, ICP_LEDGER_CANISTER_ID, LEDGER_DID)

    result = ledger.icrc1_transfer(
        {
            "from_subaccount": None,
            "to": {"owner": Principal.from_str(gamestate), "subaccount": None},
            "amount": AMOUNT_E8S,
            "fee": [FEE_E8S],
            "memo": None,  # <-- intentionally no memo for the rejection test
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
