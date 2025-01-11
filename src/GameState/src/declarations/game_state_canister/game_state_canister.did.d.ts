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
export type ChallengesResult = { 'Ok' : Array<Challenge> } |
  { 'Err' : ApiError };
export interface GameStateCanister {
  'addNewChallenge' : ActorMethod<[NewChallengeInput], ChallengeAdditionResult>,
  'addNewMainerAgentCanister' : ActorMethod<
    [MainerAgentCanisterInput],
    MainerAgentCanisterResult
  >,
  'addNewScoredResponse' : ActorMethod<
    [ScoredResponseInput],
    ScoredResponseResult
  >,
  'addOfficialCanister' : ActorMethod<[CanisterInput], AuthRecordResult>,
  'getCurrentChallenges' : ActorMethod<[], ChallengesResult>,
  'getMainerAgentCanisterInfo' : ActorMethod<
    [CanisterRetrieveInput],
    MainerAgentCanisterResult
  >,
  'getRandomOpenChallenge' : ActorMethod<[], ChallengeResult>,
  'submitChallengeResponse' : ActorMethod<
    [ChallengeResponseSubmissionInput],
    ChallengeResponseSubmissionResult
  >,
}
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
