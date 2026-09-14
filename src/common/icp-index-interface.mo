// Motoko binding for the ICP LEDGER INDEX canister, qhbym-qaaaa-aaaaa-aaafq-cai.
// https://dashboard.internetcomputer.org/canister/qhbym-qaaaa-aaaaa-aaafq-cai
//
// Not to be confused with icp-ledger-interface.mo. The index resolves archived
// transactions transparently and is queryable BY ACCOUNT, which is what makes
// discovery possible. It expresses accounts as hex TEXT where the ledger uses a
// 32-byte Blob, and it answers a malformed identifier with an EMPTY transaction
// list rather than an error - so getting that wrong looks exactly like having
// nothing to sweep.
//
// DISCOVERY only. Nothing it returns is trusted: the sidecar forwards a block id
// and GameState re-reads the block from the ledger before crediting anyone.
module IcpIndex {

    public type TimeStamp = { timestamp_nanos : Nat64 };
    public type Tokens = { e8s : Nat64 };

    // Note the index reports accounts as hex Text, where the ledger uses Blob.
    public type Operation = {
        #Approve : {
            fee : Tokens;
            from : Text;
            allowance : Tokens;
            expires_at : ?TimeStamp;
            spender : Text;
            expected_allowance : ?Tokens;
        };
        #Burn : { from : Text; amount : Tokens; spender : ?Text };
        #Mint : { to : Text; amount : Tokens };
        #Transfer : {
            to : Text;
            fee : Tokens;
            from : Text;
            amount : Tokens;
            spender : ?Text;
        };
    };

    // Unlike the ledger's CandidTransaction, `operation` here is NOT optional.
    public type Transaction = {
        memo : Nat64;
        icrc1_memo : ?Blob;
        operation : Operation;
        created_at_time : ?TimeStamp;
        timestamp : ?TimeStamp;
    };

    public type TransactionWithId = { id : Nat64; transaction : Transaction };

    // `start` is EXCLUSIVE and results come back NEWEST-FIRST. There is no forward
    // pagination: to page, pass the id of the OLDEST item in the previous page.
    public type GetAccountIdentifierTransactionsArgs = {
        max_results : Nat64;
        start : ?Nat64;
        account_identifier : Text;
    };

    public type GetAccountIdentifierTransactionsResponse = {
        balance : Nat64;
        transactions : [TransactionWithId];
        oldest_tx_id : ?Nat64;
    };

    public type GetAccountIdentifierTransactionsError = { message : Text };

    public type GetAccountIdentifierTransactionsResult = {
        #Ok : GetAccountIdentifierTransactionsResponse;
        #Err : GetAccountIdentifierTransactionsError;
    };

    public type ICP_INDEX = actor {
        get_account_identifier_transactions : shared query GetAccountIdentifierTransactionsArgs -> async GetAccountIdentifierTransactionsResult;
        ledger_id : shared query () -> async Principal;
    };
};
