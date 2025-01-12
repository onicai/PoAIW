import type { Principal } from '@dfinity/principal';
import type { ActorMethod } from '@dfinity/agent';
import type { IDL } from '@dfinity/candid';

export type ApiError = { 'FailedOperation' : null } |
  { 'InvalidId' : null } |
  { 'ZeroAddress' : null } |
  { 'Unauthorized' : null } |
  { 'StatusCode' : StatusCode } |
  { 'Other' : string };
export interface AuthRecord { 'auth' : string }
export type AuthRecordResult = { 'Ok' : AuthRecord } |
  { 'Err' : ApiError };
export type CanisterAddress = string;
export interface CanisterInput {
  'canisterType' : ProtocolCanisterType,
  'address' : CanisterAddress,
}
export interface CanisterRetrieveInput { 'address' : CanisterAddress }
export interface Challenge {
  'status' : ChallengeStatus,
  'challengePrompt' : string,
  'creationTimestamp' : bigint,
  'createdBy' : CanisterAddress,
  'responsibleJudgeAddress' : CanisterAddress,
  'challengeId' : string,
  'closedTimestamp' : [] | [bigint],
}
export type ChallengeAdditionResult = { 'Ok' : Challenge } |
  { 'Err' : ApiError };
export interface ChallengeParticipantEntry {
  'result' : ChallengeParticipationResult,
  'reward' : ChallengeWinnerReward,
  'ownedBy' : Principal,
  'submittedBy' : Principal,
  'submissionId' : string,
}
export type ChallengeParticipationResult = { 'ThirdPlace' : null } |
  { 'SecondPlace' : null } |
  { 'Winner' : null } |
  { 'Other' : string } |
  { 'Participated' : null };
export interface ChallengeResponseSubmissionInput {
  'submittedBy' : Principal,
  'challengeId' : string,
  'response' : string,
}
export type ChallengeResponseSubmissionResult = {
    'Ok' : ChallengeResponseSubmissionReturn
  } |
  { 'Err' : ApiError };
export interface ChallengeResponseSubmissionReturn {
  'status' : ChallengeResponseSubmissionStatus,
  'submittedTimestamp' : bigint,
  'success' : boolean,
  'submissionId' : string,
}
export type ChallengeResponseSubmissionStatus = { 'Judged' : null } |
  { 'FailedSubmission' : null } |
  { 'Processed' : null } |
  { 'Received' : null } |
  { 'Other' : string } |
  { 'Submitted' : null };
export type ChallengeResult = { 'Ok' : Challenge } |
  { 'Err' : ApiError };
export type ChallengeStatus = { 'Open' : null } |
  { 'Closed' : null } |
  { 'Archived' : null } |
  { 'Other' : string };
export interface ChallengeWinnerDeclaration {
  'participants' : List,
  'thirdPlace' : ChallengeParticipantEntry,
  'winner' : ChallengeParticipantEntry,
  'secondPlace' : ChallengeParticipantEntry,
  'finalizedTimestamp' : bigint,
  'challengeId' : string,
}
export interface ChallengeWinnerReward {
  'distributed' : boolean,
  'rewardDetails' : string,
  'rewardType' : RewardType,
  'amount' : bigint,
  'distributedTimestamp' : [] | [bigint],
}
export type ChallengeWinnersResult = {
    'Ok' : Array<ChallengeWinnerDeclaration>
  } |
  { 'Err' : ApiError };
export type ChallengesResult = { 'Ok' : Array<Challenge> } |
  { 'Err' : ApiError };
export interface GameStateCanister {
  'addChallenge' : ActorMethod<[NewChallengeInput], ChallengeAdditionResult>,
  'addMainerAgentCanister' : ActorMethod<
    [MainerAgentCanisterInput],
    MainerAgentCanisterResult
  >,
  'addOfficialCanister' : ActorMethod<[CanisterInput], AuthRecordResult>,
  'addScoredResponse' : ActorMethod<
    [ScoredResponseInput],
    ScoredResponseResult
  >,
  'getCurrentChallenges' : ActorMethod<[], ChallengesResult>,
  'getMainerAgentCanisterInfo' : ActorMethod<
    [CanisterRetrieveInput],
    MainerAgentCanisterResult
  >,
  'getRandomOpenChallenge' : ActorMethod<[], ChallengeResult>,
  'getRecentChallengeWinners' : ActorMethod<[], ChallengeWinnersResult>,
  'submitChallengeResponse' : ActorMethod<
    [ChallengeResponseSubmissionInput],
    ChallengeResponseSubmissionResult
  >,
}
export type List = [] | [[ChallengeParticipantEntry, List]];
export interface MainerAgentCanisterInput {
  'canisterType' : ProtocolCanisterType,
  'ownedBy' : Principal,
  'address' : CanisterAddress,
}
export type MainerAgentCanisterResult = { 'Ok' : OfficialProtocolCanister } |
  { 'Err' : ApiError };
export interface NewChallengeInput { 'challengePrompt' : string }
export interface OfficialProtocolCanister {
  'canisterType' : ProtocolCanisterType,
  'ownedBy' : Principal,
  'creationTimestamp' : bigint,
  'createdBy' : Principal,
  'address' : CanisterAddress,
}
export type ProtocolCanisterType = { 'MainerAgent' : null } |
  { 'Challenger' : null } |
  { 'Judge' : null } |
  { 'Verifier' : null } |
  { 'MainerCreator' : null };
export type RewardType = { 'ICP' : null } |
  { 'Coupon' : string } |
  { 'MainerToken' : null } |
  { 'Cycles' : null } |
  { 'Other' : string };
export interface ScoredResponseInput {
  'status' : ChallengeResponseSubmissionStatus,
  'judgedBy' : Principal,
  'submittedTimestamp' : bigint,
  'submittedBy' : Principal,
  'score' : bigint,
  'challengeId' : string,
  'response' : string,
  'submissionId' : string,
}
export type ScoredResponseResult = { 'Ok' : ScoredResponseReturn } |
  { 'Err' : ApiError };
export interface ScoredResponseReturn { 'success' : boolean }
export type StatusCode = number;
export interface _SERVICE extends GameStateCanister {}
export declare const idlFactory: IDL.InterfaceFactory;
export declare const init: (args: { IDL: typeof IDL }) => IDL.Type[];
