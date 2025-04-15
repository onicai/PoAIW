module TokenLedger {
  public type Account = { owner : Principal; subaccount : ?[Nat8] };

  public type MetadataValue = {
    #Int : Int;
    #Nat : Nat;
    #Blob : [Nat8];
    #Text : Text;
  };

  public type Result = { #Ok : Nat; #Err : TransferError };

  public type StandardRecord = { url : Text; name : Text };

  public type TransferArg = {
    to : Account;
    fee : ?Nat;
    memo : ?[Nat8];
    from_subaccount : ?[Nat8];
    created_at_time : ?Nat64;
    amount : Nat;
  };

  public type TransferError = {
    #GenericError : { message : Text; error_code : Nat };
    #TemporarilyUnavailable;
    #BadBurn : { min_burn_amount : Nat };
    #Duplicate : { duplicate_of : Nat };
    #BadFee : { expected_fee : Nat };
    #CreatedInFuture : { ledger_time : Nat64 };
    #TooOld;
    #InsufficientFunds : { balance : Nat };
  };

  public type ApproveArgs = {
      from_subaccount : ?Blob;
      spender : Account;
      amount : Nat;
      expected_allowance : ?Nat;
      expires_at : ?Nat64;
      fee : ?Nat;
      memo : ?Blob;
      created_at_time : ?Nat64;
  };

   public type ApproveError = {
      #BadFee :  { expected_fee : Nat };
      // The caller does not have enough funds to pay the approval fee.
      #InsufficientFunds :  { balance : Nat };
      // The caller specified the [expected_allowance] field, and the current
      // allowance did not match the given value.
      #AllowanceChanged :  { current_allowance : Nat };
      // The approval request expired before the ledger had a chance to apply it.
      #Expired :  { ledger_time : Nat64; };
      #TooOld;
      #CreatedInFuture:  { ledger_time : Nat64 };
      #Duplicate :  { duplicate_of : Nat };
      #TemporarilyUnavailable;
      #GenericError :  { error_code : Nat; message : Text };
  };

  public type TransferFromError =  {
      #BadFee :  { expected_fee : Nat };
      #BadBurn :  { min_burn_amount : Nat };
      // The [from] account does not hold enough funds for the transfer.
      #InsufficientFunds :  { balance : Nat };
      // The caller exceeded its allowance.
      #InsufficientAllowance :  { allowance : Nat };
      #TooOld;
      #CreatedInFuture:  { ledger_time : Nat64 };
      #Duplicate :  { duplicate_of : Nat };
      #TemporarilyUnavailable;
      #GenericError :  { error_code : Nat; message : Text };
  };

  public type TransferFromArgs =  {
      spender_subaccount : ?Blob;
      from : Account;
      to : Account;
      amount : Nat;
      fee : ?Nat;
      memo : ?Blob;
      created_at_time : ?Nat64;
  };

  public type AllowanceArgs =  {
      account : Account;
      spender : Account;
  };

  public type Allowance =  {
    allowance : Nat;
    expires_at : ?Nat64;
  };

  public type TOKEN_LEDGER = actor {
    // TODO: update to final API, incl. query blocks
    icrc1_balance_of : shared query Account -> async Nat;

    icrc1_decimals : shared query () -> async Nat8;

    icrc1_fee : shared query () -> async Nat;

    icrc1_metadata : shared query () -> async [(Text, MetadataValue)];

    icrc1_minting_account : shared query () -> async ?Account;

    icrc1_name : shared query () -> async Text;

    icrc1_supported_standards : shared query () -> async [StandardRecord];

    icrc1_symbol : shared query () -> async Text;

    icrc1_total_supply : shared query () -> async Nat;
    
    icrc1_transfer : shared TransferArg -> async Result;

    // from https://github.com/PanIndustrial-Org/icrc2.mo/blob/main/src/ICRC2/service.mo
    icrc2_approve : (ApproveArgs) -> async ({ #Ok : Nat; #Err : ApproveError });
    icrc2_transfer_from : (TransferFromArgs) -> async  { #Ok : Nat; #Err : TransferFromError };
    icrc2_allowance : query (AllowanceArgs) -> async (Allowance);
  };
}