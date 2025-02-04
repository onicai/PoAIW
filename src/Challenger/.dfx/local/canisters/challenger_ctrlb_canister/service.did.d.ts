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
export interface CanisterIDRecord { 'canister_id' : string }
export type CanisterIDRecordResult = { 'Ok' : CanisterIDRecord } |
  { 'Err' : ApiError };
export interface ChallengerCtrlbCanister {
  'add_llm_canister_id' : ActorMethod<
    [CanisterIDRecord],
    StatusCodeRecordResult
  >,
  'amiController' : ActorMethod<[], StatusCodeRecordResult>,
  'checkAccessToLLMs' : ActorMethod<[], StatusCodeRecordResult>,
  'generateNewChallenge' : ActorMethod<[], GeneratedChallengeResult>,
  'getChallengesAdmin' : ActorMethod<[], Array<GeneratedChallenge>>,
  'getChallengesListAdmin' : ActorMethod<[], List>,
  'getGameStateCanisterId' : ActorMethod<[], string>,
  'getRoundRobinCanister' : ActorMethod<[], CanisterIDRecordResult>,
  'health' : ActorMethod<[], StatusCodeRecordResult>,
  'ready' : ActorMethod<[], StatusCodeRecordResult>,
  'setGameStateCanisterId' : ActorMethod<[string], AuthRecordResult>,
  'setRoundRobinLLMs' : ActorMethod<[bigint], StatusCodeRecordResult>,
  'set_llm_canister_id' : ActorMethod<
    [CanisterIDRecord],
    StatusCodeRecordResult
  >,
  'whoami' : ActorMethod<[], Principal>,
}
export interface GeneratedChallenge {
  'generatedByLlmId' : string,
  'generationPrompt' : string,
  'generationId' : string,
  'generatedTimestamp' : bigint,
  'generatedChallengeText' : string,
}
export type GeneratedChallengeResult = { 'Ok' : GeneratedChallenge } |
  { 'Err' : ApiError };
export type List = [] | [[GeneratedChallenge, List]];
export type StatusCode = number;
export interface StatusCodeRecord { 'status_code' : number }
export type StatusCodeRecordResult = { 'Ok' : StatusCodeRecord } |
  { 'Err' : ApiError };
export interface _SERVICE extends ChallengerCtrlbCanister {}
export declare const idlFactory: IDL.InterfaceFactory;
export declare const init: (args: { IDL: typeof IDL }) => IDL.Type[];
