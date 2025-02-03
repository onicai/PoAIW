export const idlFactory = ({ IDL }) => {
  const List = IDL.Rec();
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
    'responsibleJudgeAddress' : CanisterAddress,
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
  const ChallengeResponseSubmissionStatus = IDL.Variant({
    'Judged' : IDL.Null,
    'FailedSubmission' : IDL.Null,
    'Processed' : IDL.Null,
    'Received' : IDL.Null,
    'Other' : IDL.Text,
    'Submitted' : IDL.Null,
  });
  const ScoredResponseInput = IDL.Record({
    'status' : ChallengeResponseSubmissionStatus,
    'judgedBy' : IDL.Principal,
    'submittedTimestamp' : IDL.Nat64,
    'submittedBy' : IDL.Principal,
    'score' : IDL.Nat,
    'challengeId' : IDL.Text,
    'response' : IDL.Text,
    'submissionId' : IDL.Text,
  });
  const ScoredResponseReturn = IDL.Record({ 'success' : IDL.Bool });
  const ScoredResponseResult = IDL.Variant({
    'Ok' : ScoredResponseReturn,
    'Err' : ApiError,
  });
  const SelectableMainerLLM = IDL.Variant({ 'Qwen2_5_0_5_B' : IDL.Null });
  const MainerConfigurationInput = IDL.Record({
    'aiModel' : IDL.Opt(SelectableMainerLLM),
  });
  const ChallengesResult = IDL.Variant({
    'Ok' : IDL.Vec(Challenge),
    'Err' : ApiError,
  });
  const CanisterRetrieveInput = IDL.Record({ 'address' : CanisterAddress });
  const ChallengeResult = IDL.Variant({ 'Ok' : Challenge, 'Err' : ApiError });
  const ChallengeParticipationResult = IDL.Variant({
    'ThirdPlace' : IDL.Null,
    'SecondPlace' : IDL.Null,
    'Winner' : IDL.Null,
    'Other' : IDL.Text,
    'Participated' : IDL.Null,
  });
  const RewardType = IDL.Variant({
    'ICP' : IDL.Null,
    'Coupon' : IDL.Text,
    'MainerToken' : IDL.Null,
    'Cycles' : IDL.Null,
    'Other' : IDL.Text,
  });
  const ChallengeWinnerReward = IDL.Record({
    'distributed' : IDL.Bool,
    'rewardDetails' : IDL.Text,
    'rewardType' : RewardType,
    'amount' : IDL.Nat,
    'distributedTimestamp' : IDL.Opt(IDL.Nat64),
  });
  const ChallengeParticipantEntry = IDL.Record({
    'result' : ChallengeParticipationResult,
    'reward' : ChallengeWinnerReward,
    'ownedBy' : IDL.Principal,
    'submittedBy' : IDL.Principal,
    'submissionId' : IDL.Text,
  });
  List.fill(IDL.Opt(IDL.Tuple(ChallengeParticipantEntry, List)));
  const ChallengeWinnerDeclaration = IDL.Record({
    'participants' : List,
    'thirdPlace' : ChallengeParticipantEntry,
    'winner' : ChallengeParticipantEntry,
    'secondPlace' : ChallengeParticipantEntry,
    'finalizedTimestamp' : IDL.Nat64,
    'challengeId' : IDL.Text,
  });
  const ChallengeWinnersResult = IDL.Variant({
    'Ok' : IDL.Vec(ChallengeWinnerDeclaration),
    'Err' : ApiError,
  });
  const ChallengeResponseSubmissionInput = IDL.Record({
    'submittedBy' : IDL.Principal,
    'challengeId' : IDL.Text,
    'response' : IDL.Text,
  });
  const ChallengeResponseSubmissionReturn = IDL.Record({
    'status' : ChallengeResponseSubmissionStatus,
    'submittedTimestamp' : IDL.Nat64,
    'success' : IDL.Bool,
    'submissionId' : IDL.Text,
  });
  const ChallengeResponseSubmissionResult = IDL.Variant({
    'Ok' : ChallengeResponseSubmissionReturn,
    'Err' : ApiError,
  });
  const GameStateCanister = IDL.Service({
    'addChallenge' : IDL.Func(
        [NewChallengeInput],
        [ChallengeAdditionResult],
        [],
      ),
    'addMainerAgentCanister' : IDL.Func(
        [MainerAgentCanisterInput],
        [MainerAgentCanisterResult],
        [],
      ),
    'addOfficialCanister' : IDL.Func([CanisterInput], [AuthRecordResult], []),
    'addScoredResponse' : IDL.Func(
        [ScoredResponseInput],
        [ScoredResponseResult],
        [],
      ),
    'createUserMainerAgentCanister' : IDL.Func(
        [MainerConfigurationInput],
        [MainerAgentCanisterResult],
        [],
      ),
    'getCurrentChallenges' : IDL.Func([], [ChallengesResult], ['query']),
    'getCurrentChallengesAdmin' : IDL.Func([], [ChallengesResult], ['query']),
    'getMainerAgentCanisterInfo' : IDL.Func(
        [CanisterRetrieveInput],
        [MainerAgentCanisterResult],
        ['query'],
      ),
    'getOfficialChallengerCanisters' : IDL.Func([], [AuthRecordResult], []),
    'getRandomOpenChallenge' : IDL.Func([], [ChallengeResult], []),
    'getRecentChallengeWinners' : IDL.Func(
        [],
        [ChallengeWinnersResult],
        ['query'],
      ),
    'submitChallengeResponse' : IDL.Func(
        [ChallengeResponseSubmissionInput],
        [ChallengeResponseSubmissionResult],
        [],
      ),
  });
  return GameStateCanister;
};
export const init = ({ IDL }) => { return []; };
