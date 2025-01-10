import type { Principal } from '@dfinity/principal';
import type { ActorMethod } from '@dfinity/agent';
import type { IDL } from '@dfinity/candid';

export type ApiError = { 'InvalidId' : null } |
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
  'challengePrompt' : string,
  'creationTimestamp' : bigint,
  'createdBy' : CanisterAddress,
  'challengeId' : string,
  'closedTimestamp' : [] | [bigint],
}
export type ChallengeAdditionResult = { 'Ok' : Challenge } |
  { 'Err' : ApiError };
export type ChallengesResult = { 'Ok' : Array<Challenge> } |
  { 'Err' : ApiError };
export interface GameStateCanister {
  'addNewChallenge' : ActorMethod<[NewChallengeInput], ChallengeAdditionResult>,
  'addNewMainerAgentCanister' : ActorMethod<
    [MainerAgentCanisterInput],
    MainerAgentCanisterResult
  >,
  'addOfficialCanister' : ActorMethod<[CanisterInput], AuthRecordResult>,
  'getCurrentChallenges' : ActorMethod<[], ChallengesResult>,
  'getMainerAgentCanisterInfo' : ActorMethod<
    [CanisterRetrieveInput],
    MainerAgentCanisterResult
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
export type StatusCode = number;
export interface _SERVICE extends GameStateCanister {}
export declare const idlFactory: IDL.InterfaceFactory;
export declare const init: (args: { IDL: typeof IDL }) => IDL.Type[];
