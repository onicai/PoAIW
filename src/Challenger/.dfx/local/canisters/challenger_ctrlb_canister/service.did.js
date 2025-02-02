export const idlFactory = ({ IDL }) => {
  const CanisterIDRecord = IDL.Record({ 'canister_id' : IDL.Text });
  const StatusCodeRecord = IDL.Record({ 'status_code' : IDL.Nat16 });
  const StatusCode = IDL.Nat16;
  const ApiError = IDL.Variant({
    'FailedOperation' : IDL.Null,
    'InvalidId' : IDL.Null,
    'ZeroAddress' : IDL.Null,
    'Unauthorized' : IDL.Null,
    'StatusCode' : StatusCode,
    'Other' : IDL.Text,
  });
  const StatusCodeRecordResult = IDL.Variant({
    'Ok' : StatusCodeRecord,
    'Err' : ApiError,
  });
  const GeneratedChallenge = IDL.Record({
    'generatedByLlmId' : IDL.Text,
    'generationPrompt' : IDL.Text,
    'generationId' : IDL.Text,
    'generatedTimestamp' : IDL.Nat64,
    'generatedChallengeText' : IDL.Text,
  });
  const GeneratedChallengeResult = IDL.Variant({
    'Ok' : GeneratedChallenge,
    'Err' : ApiError,
  });
  const CanisterIDRecordResult = IDL.Variant({
    'Ok' : CanisterIDRecord,
    'Err' : ApiError,
  });
  const AuthRecord = IDL.Record({ 'auth' : IDL.Text });
  const AuthRecordResult = IDL.Variant({ 'Ok' : AuthRecord, 'Err' : ApiError });
  const ChallengerCtrlbCanister = IDL.Service({
    'add_llm_canister_id' : IDL.Func(
        [CanisterIDRecord],
        [StatusCodeRecordResult],
        [],
      ),
    'amiController' : IDL.Func([], [StatusCodeRecordResult], ['query']),
    'checkAccessToLLMs' : IDL.Func([], [StatusCodeRecordResult], []),
    'generateNewChallenge' : IDL.Func([], [GeneratedChallengeResult], []),
    'getGameStateCanisterId' : IDL.Func([], [IDL.Text], ['query']),
    'getRoundRobinCanister' : IDL.Func([], [CanisterIDRecordResult], ['query']),
    'health' : IDL.Func([], [StatusCodeRecordResult], ['query']),
    'ready' : IDL.Func([], [StatusCodeRecordResult], []),
    'setGameStateCanisterId' : IDL.Func([IDL.Text], [AuthRecordResult], []),
    'setRoundRobinLLMs' : IDL.Func([IDL.Nat], [StatusCodeRecordResult], []),
    'set_llm_canister_id' : IDL.Func(
        [CanisterIDRecord],
        [StatusCodeRecordResult],
        [],
      ),
    'whoami' : IDL.Func([], [IDL.Principal], ['query']),
  });
  return ChallengerCtrlbCanister;
};
export const init = ({ IDL }) => { return []; };
