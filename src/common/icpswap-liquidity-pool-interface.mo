// This is a generated Motoko binding: https://dashboard.internetcomputer.org/canister/c5u7l-rqaaa-aaaar-qbqta-cai
// Please use `import service "ic:canister_id"` instead to call canisters on the IC if possible.

module LiquidityPool {
  public type Account = { owner : Principal; subaccount : ?Blob };
  public type AccountBalance = { balance0 : Nat; balance1 : Nat };
  public type Action = {
    #Withdraw : WithdrawInfo;
    #RemoveLimitOrder : RemoveLimitOrderInfo;
    #AddLiquidity : AddLiquidityInfo;
    #OneStepSwap : OneStepSwapInfo;
    #Deposit : DepositInfo;
    #Refund : RefundInfo;
    #Swap : SwapInfo;
    #ExecuteLimitOrder : ExecuteLimitOrderInfo;
    #TransferPosition : TransferPositionInfo;
    #DecreaseLiquidity : DecreaseLiquidityInfo;
    #Claim : ClaimInfo;
    #AddLimitOrder : AddLimitOrderInfo;
  };
  public type AddLimitOrderInfo = {
    err : ?Error__1;
    status : AddLimitOrderStatus;
    token1AmountIn : Nat;
    token0AmountIn : Nat;
    positionId : Nat;
    token0 : Token__1;
    token1 : Token__1;
    tickLimit : Int;
  };
  public type AddLimitOrderStatus = { #Failed; #Created; #Completed };
  public type AddLiquidityInfo = {
    err : ?Error__1;
    status : AddLiquidityStatus;
    liquidity : Nat;
    positionId : Nat;
    amount0 : Nat;
    amount1 : Nat;
    token0 : Token__1;
    token1 : Token__1;
  };
  public type AddLiquidityStatus = { #Failed; #Created; #Completed };
  public type Amount = Nat;
  public type ClaimArgs = { positionId : Nat };
  public type ClaimInfo = {
    err : ?Error__1;
    status : ClaimStatus;
    positionId : Nat;
    amount0 : Nat;
    amount1 : Nat;
    token0 : Token__1;
    token1 : Token__1;
  };
  public type ClaimStatus = { #Failed; #Created; #Completed };
  public type CycleInfo = { balance : Nat; available : Nat };
  public type DecreaseLiquidityArgs = { liquidity : Text; positionId : Nat };
  public type DecreaseLiquidityInfo = {
    err : ?Error__1;
    status : DecreaseLiquidityStatus;
    liquidity : Nat;
    positionId : Nat;
    amount0 : Nat;
    amount1 : Nat;
    token0 : Token__1;
    token1 : Token__1;
  };
  public type DecreaseLiquidityStatus = { #Failed; #Created; #Completed };
  public type DepositAndMintArgs = {
    tickUpper : Int;
    fee0 : Nat;
    fee1 : Nat;
    amount0 : Nat;
    amount1 : Nat;
    positionOwner : Principal;
    amount0Desired : Text;
    amount1Desired : Text;
    tickLower : Int;
  };
  public type DepositAndSwapArgs = {
    tokenInFee : Nat;
    amountIn : Text;
    zeroForOne : Bool;
    amountOutMinimum : Text;
    tokenOutFee : Nat;
  };
  public type DepositArgs = { fee : Nat; token : Text; amount : Nat };
  public type DepositInfo = {
    err : ?Error__1;
    status : DepositStatus;
    transfer : Transfer;
  };
  public type DepositStatus = {
    #Failed;
    #TransferCompleted;
    #Created;
    #Completed;
  };
  public type Error = {
    #CommonError;
    #InternalError : Text;
    #UnsupportedToken : Text;
    #InsufficientFunds;
  };
  public type Error__1 = Text;
  public type ExecuteLimitOrderInfo = {
    err : ?Error__1;
    status : ExecuteLimitOrderStatus;
    token1AmountIn : Nat;
    token0AmountIn : Nat;
    positionId : Nat;
    token1AmountOut : Nat;
    token0 : Token__1;
    token1 : Token__1;
    token0AmountOut : Nat;
    tickLimit : Int;
  };
  public type ExecuteLimitOrderStatus = { #Failed; #Created; #Completed };
  public type GetPositionArgs = { tickUpper : Int; tickLower : Int };
  public type Icrc21ConsentInfo = {
    metadata : Icrc21ConsentMessageMetadata;
    consent_message : Icrc21ConsentMessage;
  };
  public type Icrc21ConsentMessage = {
    #LineDisplayMessage : { pages : [{ lines : [Text] }] };
    #GenericDisplayMessage : Text;
  };
  public type Icrc21ConsentMessageMetadata = {
    utc_offset_minutes : ?Int16;
    language : Text;
  };
  public type Icrc21ConsentMessageRequest = {
    arg : Blob;
    method : Text;
    user_preferences : Icrc21ConsentMessageSpec;
  };
  public type Icrc21ConsentMessageResponse = {
    #Ok : Icrc21ConsentInfo;
    #Err : Icrc21Error;
  };
  public type Icrc21ConsentMessageSpec = {
    metadata : Icrc21ConsentMessageMetadata;
    device_spec : ?{
      #GenericDisplay;
      #LineDisplay : { characters_per_line : Nat16; lines_per_page : Nat16 };
    };
  };
  public type Icrc21Error = {
    #GenericError : { description : Text; error_code : Nat };
    #InsufficientPayment : Icrc21ErrorInfo;
    #UnsupportedCanisterCall : Icrc21ErrorInfo;
    #ConsentMessageUnavailable : Icrc21ErrorInfo;
  };
  public type Icrc21ErrorInfo = { description : Text };
  public type Icrc28TrustedOriginsResponse = { trusted_origins : [Text] };
  public type IncreaseLiquidityArgs = {
    positionId : Nat;
    amount0Desired : Text;
    amount1Desired : Text;
  };
  public type JobInfo = {
    interval : Nat;
    name : Text;
    lastRun : Time;
    timerId : ?Nat;
  };
  public type Level = { #Inactive; #Active };
  public type LimitOrderArgs = { positionId : Nat; tickLimit : Int };
  public type LimitOrderKey = { timestamp : Nat; tickLimit : Int };
  public type LimitOrderType = { #Lower; #Upper };
  public type LimitOrderValue = {
    userPositionId : Nat;
    token0InAmount : Nat;
    owner : Principal;
    token1InAmount : Nat;
  };
  public type MintArgs = {
    fee : Nat;
    tickUpper : Int;
    token0 : Text;
    token1 : Text;
    amount0Desired : Text;
    amount1Desired : Text;
    tickLower : Int;
  };
  public type OneStepSwapInfo = {
    err : ?Error__1;
    status : OneStepSwapStatus;
    withdraw : WithdrawInfo;
    swap : SwapInfo;
    deposit : DepositInfo;
  };
  public type OneStepSwapStatus = {
    #SwapCompleted;
    #Failed;
    #PreSwapCompleted;
    #DepositCreditCompleted;
    #DepositTransferCompleted;
    #Created;
    #WithdrawCreditCompleted;
    #Completed;
  };
  public type Page = {
    content : [UserPositionInfoWithId];
    offset : Nat;
    limit : Nat;
    totalElements : Nat;
  };
  public type Page_1 = {
    content : [UserPositionInfoWithTokenAmount];
    offset : Nat;
    limit : Nat;
    totalElements : Nat;
  };
  public type Page_2 = {
    content : [TickInfoWithId];
    offset : Nat;
    limit : Nat;
    totalElements : Nat;
  };
  public type Page_3 = {
    content : [TickLiquidityInfo];
    offset : Nat;
    limit : Nat;
    totalElements : Nat;
  };
  public type Page_4 = {
    content : [PositionInfoWithId];
    offset : Nat;
    limit : Nat;
    totalElements : Nat;
  };
  public type Page_5 = {
    content : [(Principal, AccountBalance)];
    offset : Nat;
    limit : Nat;
    totalElements : Nat;
  };
  public type PoolInitArgs = {
    infoCid : Principal;
    positionIndexCid : Principal;
    trustedCanisterManagerCid : Principal;
    token0 : Token;
    token1 : Token;
    feeReceiverCid : Principal;
  };
  public type PoolMetadata = {
    fee : Nat;
    key : Text;
    sqrtPriceX96 : Nat;
    tick : Int;
    liquidity : Nat;
    token0 : Token;
    token1 : Token;
    maxLiquidityPerTick : Nat;
    nextPositionId : Nat;
  };
  public type PositionInfo = {
    tokensOwed0 : Nat;
    tokensOwed1 : Nat;
    feeGrowthInside1LastX128 : Nat;
    liquidity : Nat;
    feeGrowthInside0LastX128 : Nat;
  };
  public type PositionInfoWithId = {
    id : Text;
    tokensOwed0 : Nat;
    tokensOwed1 : Nat;
    feeGrowthInside1LastX128 : Nat;
    liquidity : Nat;
    feeGrowthInside0LastX128 : Nat;
  };
  public type PushError = { time : Int; message : Text };
  public type RefundInfo = {
    err : ?Error__1;
    status : RefundStatus;
    relatedIndex : Nat;
    transfer : Transfer;
  };
  public type RefundStatus = {
    #Failed;
    #CreditCompleted;
    #Created;
    #Completed;
  };
  public type RemoveLimitOrderInfo = {
    err : ?Error__1;
    status : RemoveLimitOrderStatus;
    token1AmountIn : Nat;
    token0AmountIn : Nat;
    positionId : Nat;
    token1AmountOut : Nat;
    token0 : Token__1;
    token1 : Token__1;
    token0AmountOut : Nat;
    tickLimit : Int;
  };
  public type RemoveLimitOrderStatus = {
    #Failed;
    #LimitOrderDeleted;
    #Created;
    #Completed;
  };
  public type Result = { #ok : Nat; #err : Error };
  public type Result_1 = { #ok : Text; #err : Error };
  public type Result_10 = { #ok : Page; #err : Error };
  public type Result_11 = { #ok : Page_1; #err : Error };
  public type Result_12 = { #ok : [Nat]; #err : Error };
  public type Result_13 = { #ok : [(Text, [Nat])]; #err : Error };
  public type Result_14 = { #ok : UserPositionInfo; #err : Error };
  public type Result_15 = {
    #ok : {
      upperLimitOrdersIds : [{ userPositionId : Nat; timestamp : Nat }];
      lowerLimitOrderIds : [{ userPositionId : Nat; timestamp : Nat }];
    };
    #err : Error;
  };
  public type Result_16 = { #ok : [(Nat, Transaction)]; #err : Error };
  public type Result_17 = {
    #ok : {
      swapFee0Repurchase : Nat;
      token0Amount : Nat;
      swapFeeReceiver : Text;
      token1Amount : Nat;
      swapFee1Repurchase : Nat;
    };
    #err : Error;
  };
  public type Result_18 = { #ok : Page_2; #err : Error };
  public type Result_19 = { #ok : Page_3; #err : Error };
  public type Result_2 = { #ok : Bool; #err : Error };
  public type Result_20 = { #ok : [(Int, Nat)]; #err : Error };
  public type Result_21 = {
    #ok : {
      infoCid : Text;
      records : [SwapRecordInfo];
      errors : [PushError];
      retryCount : Nat;
    };
    #err : Error;
  };
  public type Result_22 = {
    #ok : [
      {
        userPositionId : Nat;
        token0InAmount : Nat;
        timestamp : Nat;
        tickLimit : Int;
        token1InAmount : Nat;
      }
    ];
    #err : Error;
  };
  public type Result_23 = { #ok : Page_4; #err : Error };
  public type Result_24 = { #ok : PositionInfo; #err : Error };
  public type Result_25 = {
    #ok : {
      lowerLimitOrders : [(LimitOrderKey, LimitOrderValue)];
      upperLimitOrders : [(LimitOrderKey, LimitOrderValue)];
    };
    #err : Error;
  };
  public type Result_26 = {
    #ok : [(LimitOrderType, LimitOrderKey, LimitOrderValue)];
    #err : Error;
  };
  public type Result_27 = { #ok : PoolInitArgs; #err : Error };
  public type Result_28 = {
    #ok : { feeGrowthGlobal1X128 : Nat; feeGrowthGlobal0X128 : Nat };
    #err : Error;
  };
  public type Result_29 = { #ok : CycleInfo; #err : Error };
  public type Result_3 = { #ok : Int; #err : Error };
  public type Result_30 = {
    #ok : { amount0 : Nat; amount1 : Nat };
    #err : Error;
  };
  public type Result_31 = {
    #ok : {
      tokenIncome : [(Nat, { tokensOwed0 : Nat; tokensOwed1 : Nat })];
      totalTokensOwed0 : Nat;
      totalTokensOwed1 : Nat;
    };
    #err : Error;
  };
  public type Result_32 = { #ok : Page_5; #err : Error };
  public type Result_4 = { #ok; #err : Error };
  public type Result_5 = { #ok : Bool; #err };
  public type Result_6 = {
    #ok : { tokensOwed0 : Nat; tokensOwed1 : Nat };
    #err : Error;
  };
  public type Result_7 = { #ok : PoolMetadata; #err : Error };
  public type Result_8 = {
    #ok : { balance0 : Nat; balance1 : Nat };
    #err : Error;
  };
  public type Result_9 = { #ok : [UserPositionInfoWithId]; #err : Error };
  public type SwapArgs = {
    amountIn : Text;
    zeroForOne : Bool;
    amountOutMinimum : Text;
  };
  public type SwapInfo = {
    err : ?Error__1;
    status : SwapStatus;
    tokenIn : Token__1;
    tokenOut : Token__1;
    amountOutFee : Nat;
    amountIn : Amount;
    amountOut : Nat;
    amountInFee : Nat;
  };
  public type SwapRecordInfo = {
    currentLiquidity : Nat;
    currentSqrtPriceX96 : Nat;
    currentTick : Int;
    txInfo : Transaction__1;
    poolFee : Nat;
  };
  public type SwapStatus = { #Failed; #Created; #Completed };
  public type TickInfoWithId = {
    id : Text;
    initialized : Bool;
    feeGrowthOutside1X128 : Nat;
    secondsPerLiquidityOutsideX128 : Nat;
    liquidityNet : Int;
    secondsOutside : Nat;
    liquidityGross : Nat;
    feeGrowthOutside0X128 : Nat;
    tickCumulativeOutside : Int;
  };
  public type TickLiquidityInfo = {
    tickIndex : Int;
    price0Decimal : Nat;
    liquidityNet : Int;
    price0 : Nat;
    price1 : Nat;
    liquidityGross : Nat;
    price1Decimal : Nat;
  };
  public type Time = Int;
  public type Token = { address : Text; standard : Text };
  public type Token__1 = { address : Principal; standard : Text };
  public type Transaction = {
    id : Nat;
    action : Action;
    owner : Principal;
    timestamp : Time;
    canisterId : Principal;
  };
  public type Transaction__1 = {
    id : Nat;
    action : Action;
    owner : Principal;
    timestamp : Time;
    canisterId : Principal;
  };
  public type Transfer = {
    to : Account;
    fee : Nat;
    token : Principal;
    from : Account;
    memo : ?Blob;
    index : Nat;
    amount : Nat;
    standard : Text;
  };
  public type TransferPositionInfo = {
    to : Account;
    err : ?Error__1;
    status : TransferPositionStatus;
    from : Account;
    positionId : Nat;
    token0Amount : Nat;
    token1Amount : Nat;
  };
  public type TransferPositionStatus = { #Failed; #Created; #Completed };
  public type UserPositionInfo = {
    tickUpper : Int;
    tokensOwed0 : Nat;
    tokensOwed1 : Nat;
    feeGrowthInside1LastX128 : Nat;
    liquidity : Nat;
    feeGrowthInside0LastX128 : Nat;
    tickLower : Int;
  };
  public type UserPositionInfoWithId = {
    id : Nat;
    tickUpper : Int;
    tokensOwed0 : Nat;
    tokensOwed1 : Nat;
    feeGrowthInside1LastX128 : Nat;
    liquidity : Nat;
    feeGrowthInside0LastX128 : Nat;
    tickLower : Int;
  };
  public type UserPositionInfoWithTokenAmount = {
    id : Nat;
    tickUpper : Int;
    tokensOwed0 : Nat;
    tokensOwed1 : Nat;
    feeGrowthInside1LastX128 : Nat;
    liquidity : Nat;
    feeGrowthInside0LastX128 : Nat;
    token0Amount : Nat;
    token1Amount : Nat;
    tickLower : Int;
  };
  public type WithdrawArgs = { fee : Nat; token : Text; amount : Nat };
  public type WithdrawInfo = {
    err : ?Error__1;
    status : WithdrawStatus;
    transfer : Transfer;
  };
  public type WithdrawStatus = {
    #Failed;
    #CreditCompleted;
    #Created;
    #Completed;
  };
  public type WithdrawToSubaccountArgs = {
    fee : Nat;
    token : Text;
    subaccount : Blob;
    amount : Nat;
  };
  public type LIQUIDITY_POOL = actor {
    activeJobs : shared () -> async ();
    addLimitOrder : shared LimitOrderArgs -> async Result_2;
    allTokenBalance : shared query (Nat, Nat) -> async Result_32;
    approvePosition : shared (Principal, Nat) -> async Result_2;
    batchRefreshIncome : shared query [Nat] -> async Result_31;
    checkOwnerOfUserPosition : shared query (Principal, Nat) -> async Result_2;
    claim : shared ClaimArgs -> async Result_30;
    decreaseLiquidity : shared DecreaseLiquidityArgs -> async Result_30;
    deleteFailedTransaction : shared (Nat, Bool) -> async Result_2;
    deposit : shared DepositArgs -> async Result;
    depositAllAndMint : shared DepositAndMintArgs -> async Result;
    depositAndSwap : shared DepositAndSwapArgs -> async Result;
    depositFrom : shared DepositArgs -> async Result;
    depositFromAndSwap : shared DepositAndSwapArgs -> async Result;
    getAdmins : shared query () -> async [Principal];
    getAvailabilityState : shared query () -> async {
        whiteList : [Principal];
        available : Bool;
      };
    getCachedTokenFee : shared query () -> async {
        token0Fee : Nat;
        token1Fee : Nat;
      };
    getClaimLog : shared query () -> async [Text];
    getCycleInfo : shared () -> async Result_29;
    getFailedTransactions : shared query () -> async Result_16;
    getFeeGrowthGlobal : shared query () -> async Result_28;
    getInitArgs : shared query () -> async Result_27;
    getJobs : shared query () -> async { jobs : [JobInfo]; level : Level };
    getLimitOrderAvailabilityState : shared query () -> async Result_2;
    getLimitOrderStack : shared query () -> async Result_26;
    getLimitOrders : shared query () -> async Result_25;
    getMistransferBalance : shared Token -> async Result;
    getPosition : shared query GetPositionArgs -> async Result_24;
    getPositions : shared query (Nat, Nat) -> async Result_23;
    getSortedUserLimitOrders : shared query Principal -> async Result_22;
    getSwapRecordState : shared query () -> async Result_21;
    getTickBitmaps : shared query () -> async Result_20;
    getTickInfos : shared query (Nat, Nat) -> async Result_19;
    getTicks : shared query (Nat, Nat) -> async Result_18;
    getTokenAmountState : shared query () -> async Result_17;
    getTokenBalance : shared () -> async { token0 : Nat; token1 : Nat };
    getTransactions : shared query () -> async Result_16;
    getTransactionsByOwner : shared query Principal -> async Result_16;
    getUserByPositionId : shared query Nat -> async Result_1;
    getUserLimitOrders : shared query Principal -> async Result_15;
    getUserPosition : shared query Nat -> async Result_14;
    getUserPositionIds : shared query () -> async Result_13;
    getUserPositionIdsByPrincipal : shared query Principal -> async Result_12;
    getUserPositionWithTokenAmount : shared query (Nat, Nat) -> async Result_11;
    getUserPositions : shared query (Nat, Nat) -> async Result_10;
    getUserPositionsByPrincipal : shared query Principal -> async Result_9;
    getUserUnusedBalance : shared query Principal -> async Result_8;
    getVersion : shared query () -> async Text;
    icrc10_supported_standards : shared query () -> async [
        { url : Text; name : Text }
      ];
    icrc21_canister_call_consent_message : shared Icrc21ConsentMessageRequest -> async Icrc21ConsentMessageResponse;
    icrc28_trusted_origins : shared () -> async Icrc28TrustedOriginsResponse;
    increaseLiquidity : shared IncreaseLiquidityArgs -> async Result;
    init : shared (Nat, Int, Nat) -> async ();
    metadata : shared query () -> async Result_7;
    mint : shared MintArgs -> async Result;
    quote : shared query SwapArgs -> async Result;
    quoteForAll : shared query SwapArgs -> async Result;
    refreshIncome : shared query Nat -> async Result_6;
    removeLimitOrder : shared Nat -> async Result_2;
    restartJobs : shared [Text] -> async ();
    setAdmins : shared [Principal] -> async ();
    setAvailable : shared Bool -> async ();
    setIcrc28TrustedOrigins : shared [Text] -> async Result_5;
    setLimitOrderAvailable : shared Bool -> async ();
    setTokenAmountState : shared (Nat, Nat) -> async Result_4;
    setWhiteList : shared [Principal] -> async ();
    stopJobs : shared [Text] -> async ();
    sumTick : shared query () -> async Result_3;
    swap : shared SwapArgs -> async Result;
    transferPosition : shared (Principal, Principal, Nat) -> async Result_2;
    updateTokenFee : shared () -> async ();
    upgradeTokenStandard : shared Principal -> async Result_1;
    withdraw : shared WithdrawArgs -> async Result;
    withdrawMistransferBalance : shared Token -> async Result;
    withdrawToSubaccount : shared WithdrawToSubaccountArgs -> async Result;
  }
}