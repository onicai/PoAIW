#!/usr/bin/env python3
"""
Send 0.1 ICP from the `topup-tester` identity to GameState's ledger account
with an ICRC-1 memo blob that binds the payment to a given target mAIner.

Why this script exists (instead of `dfx ledger transfer` or `dfx canister call
... icrc1_transfer ...`):
  - `dfx ledger transfer` (legacy) only accepts an 8-byte `--memo <Nat64>`,
    so it can't carry the 11-byte bound memo at all.
  - `dfx 0.29.x canister call ... icrc1_transfer "(record { ... memo = opt
    blob \"\\AD\\00...\"; ... })"` mis-parses the blob hex-escapes — an 11-byte
    memo (1 marker + 10 principal bytes) is inflated past the ICP ledger's
    32-byte MEMO_SIZE_BYTES limit and traps with `the memo field is too large`.
  - `icp-py-core` encodes the memo blob correctly. Verified end-to-end: the
    same 11-byte memo sent here is accepted by the ledger.

The redeem step (`dfx canister call <GameState> topUpCyclesForAnyMainerAgent
...`) does not have the blob-escape issue and remains a plain dfx call.

Usage:
    # bound memo, for topUpCyclesForMainerAgent / topUpCyclesForAnyMainerAgent
    python3 pay_topup.py <target_mainer_canister_id> <gamestate_canister_id>

    # plain ASCII memo, for notifyMainerTopUp (full canister id or a >= 8 char prefix)
    python3 pay_topup.py <target_mainer_canister_id> <gamestate_canister_id> --memo-text 2r3eo-5q

    # against a local icp-cli network, with a custom amount
    python3 pay_topup.py <target> <gamestate> --memo-text <prefix> --e8s 9000000 --url http://127.0.0.1:8000

Prereqs:
  - `pip install icp-py-core` in the active env (the `funnAI`
    conda env already has it).
  - `dfx identity export topup-tester > ~/.config/dfx/identity/topup-tester/identity.pem`
    (one-time, decrypts the keyring-stored PEM).

On success, prints the ICP-ledger block index on stdout (capture-friendly):
    BLOCK=$(python3 pay_topup.py "$TARGET_MAINER" "$SUBNET_0_1_GAMESTATE")
"""

import argparse
import os
import sys

from icp_agent import Agent, Client
from icp_canister import Canister
from icp_identity import Identity
from icp_principal import Principal

MEMO_PAYMENT_MARKER = 0xAD
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


DEFAULT_URL = "https://ic0.app"


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Transfer ICP to GameState with a memo identifying the target mAIner."
    )
    parser.add_argument("target_mainer", help="target mAIner canister id")
    parser.add_argument("gamestate", help="GameState canister id")
    parser.add_argument(
        "--memo-text",
        metavar="TEXT",
        help="Send TEXT as a plain ASCII icrc1_memo instead of the bound "
             "[0xAD]+principal memo. This is what notifyMainerTopUp expects: the "
             "target mAIner's canister id, or an unambiguous prefix of it "
             "(>= 8 characters, '-' included).",
    )
    parser.add_argument(
        "--e8s",
        type=int,
        default=AMOUNT_E8S,
        help=f"amount to transfer in e8s (default {AMOUNT_E8S} = 0.1 ICP)",
    )
    parser.add_argument(
        "--url",
        default=DEFAULT_URL,
        help=f"ledger endpoint (default {DEFAULT_URL}). For a local icp-cli network, "
             "read the gateway from `icp network status --json`.",
    )
    parser.add_argument(
        "--pem",
        default=TOPUP_TESTER_PEM,
        help="path to the plaintext PEM of the paying identity",
    )
    args = parser.parse_args()

    if not os.path.exists(args.pem):
        print(
            f"ERROR: no plaintext PEM at {args.pem}.\n"
            f"Run: dfx identity export topup-tester > {args.pem}",
            file=sys.stderr,
        )
        return 1

    with open(args.pem) as f:
        identity = Identity.from_pem(f.read())
    # A trailing slash produces a double slash in the request path and the replica
    # answers 400. `icp network status --json` reports the gateway with one.
    agent = Agent(identity, Client(url=args.url.rstrip("/")))
    ledger = Canister(agent, ICP_LEDGER_CANISTER_ID, LEDGER_DID)

    if args.memo_text is not None:
        # Plain ASCII, for notifyMainerTopUp. The ledger caps a memo at 32 bytes.
        memo = args.memo_text.encode("ascii")
        if len(memo) > 32:
            print(
                f"ERROR: --memo-text is {len(memo)} bytes, over the ledger's 32-byte limit",
                file=sys.stderr,
            )
            return 1
    else:
        # Bound memo, for topUpCyclesForMainerAgent / topUpCyclesForAnyMainerAgent.
        target = Principal.from_str(args.target_mainer)
        memo = bytes([MEMO_PAYMENT_MARKER]) + target.bytes

    result = ledger.icrc1_transfer(
        {
            "from_subaccount": None,
            "to": {"owner": Principal.from_str(args.gamestate), "subaccount": None},
            "amount": args.e8s,
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
