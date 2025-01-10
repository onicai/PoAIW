export const idlFactory = ({ IDL }) => {
  const NewChallengeInput = IDL.Record({ 'challengePrompt' : IDL.Text });
  const CanisterAddress = IDL.Text;
  const Challenge = IDL.Record({
    'challengePrompt' : IDL.Text,
    'creationTimestamp' : IDL.Nat64,
    'createdBy' : CanisterAddress,
    'challengeId' : IDL.Text,
    'closedTimestamp' : IDL.Opt(IDL.Nat64),
  });
  const StatusCode = IDL.Nat16;
  const ApiError = IDL.Variant({
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
    'Challenger' : IDL.Null,
    'Judge' : IDL.Null,
    'Verifier' : IDL.Null,
    'MAInerAgent' : IDL.Null,
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
  const GameStateCanister = IDL.Service({
    'addNewChallenge' : IDL.Func(
        [NewChallengeInput],
        [ChallengeAdditionResult],
        [],
      ),
    'addOfficialCanister' : IDL.Func([CanisterInput], [AuthRecordResult], []),
    'getCurrentChallenges' : IDL.Func([], [ChallengesResult], []),
  });
  return GameStateCanister;
};
export const init = ({ IDL }) => { return []; };
