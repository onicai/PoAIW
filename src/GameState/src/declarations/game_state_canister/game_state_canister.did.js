export const idlFactory = ({ IDL }) => {
  const NewChallengeInput = IDL.Record({ 'challengePrompt' : IDL.Text });
  const ChallengeStatus = IDL.Variant({
    'Open' : IDL.Null,
    'Closed' : IDL.Null,
    'Archived' : IDL.Null,
    'Other' : IDL.Text,
  });
  const CanisterAddress = IDL.Text;
  const Challenge = IDL.Record({
    'status' : ChallengeStatus,
    'challengePrompt' : IDL.Text,
    'creationTimestamp' : IDL.Nat64,
    'createdBy' : CanisterAddress,
    'challengeId' : IDL.Text,
    'closedTimestamp' : IDL.Opt(IDL.Nat64),
  });
  const StatusCode = IDL.Nat16;
  const ApiError = IDL.Variant({
    'FailedOperation' : IDL.Null,
    'InvalidId' : IDL.Null,
    'ZeroAddress' : IDL.Null,
    'Unauthorized' : IDL.Null,
    'StatusCode' : StatusCode,
    'Other' : IDL.Text,
  });
  const ChallengeAdditionResult = IDL.Variant({
    'Ok' : Challenge,
    'Err' : ApiError,
  });
  const ProtocolCanisterType = IDL.Variant({
    'MainerAgent' : IDL.Null,
    'Challenger' : IDL.Null,
    'Judge' : IDL.Null,
    'Verifier' : IDL.Null,
    'MainerCreator' : IDL.Null,
  });
  const MainerAgentCanisterInput = IDL.Record({
    'canisterType' : ProtocolCanisterType,
    'ownedBy' : IDL.Principal,
    'address' : CanisterAddress,
  });
  const OfficialProtocolCanister = IDL.Record({
    'canisterType' : ProtocolCanisterType,
    'ownedBy' : IDL.Principal,
    'creationTimestamp' : IDL.Nat64,
    'createdBy' : IDL.Principal,
    'address' : CanisterAddress,
  });
  const MainerAgentCanisterResult = IDL.Variant({
    'Ok' : OfficialProtocolCanister,
    'Err' : ApiError,
  });
  const CanisterInput = IDL.Record({
    'canisterType' : ProtocolCanisterType,
    'address' : CanisterAddress,
  });
  const AuthRecord = IDL.Record({ 'auth' : IDL.Text });
  const AuthRecordResult = IDL.Variant({ 'Ok' : AuthRecord, 'Err' : ApiError });
  const ChallengesResult = IDL.Variant({
    'Ok' : IDL.Vec(Challenge),
    'Err' : ApiError,
  });
  const CanisterRetrieveInput = IDL.Record({ 'address' : CanisterAddress });
  const ChallengeResult = IDL.Variant({ 'Ok' : Challenge, 'Err' : ApiError });
  const GameStateCanister = IDL.Service({
    'addNewChallenge' : IDL.Func(
        [NewChallengeInput],
        [ChallengeAdditionResult],
        [],
      ),
    'addNewMainerAgentCanister' : IDL.Func(
        [MainerAgentCanisterInput],
        [MainerAgentCanisterResult],
        [],
      ),
    'addOfficialCanister' : IDL.Func([CanisterInput], [AuthRecordResult], []),
    'getCurrentChallenges' : IDL.Func([], [ChallengesResult], ['query']),
    'getMainerAgentCanisterInfo' : IDL.Func(
        [CanisterRetrieveInput],
        [MainerAgentCanisterResult],
        ['query'],
      ),
    'getRandomOpenChallenge' : IDL.Func([], [ChallengeResult], []),
  });
  return GameStateCanister;
};
export const init = ({ IDL }) => { return []; };
