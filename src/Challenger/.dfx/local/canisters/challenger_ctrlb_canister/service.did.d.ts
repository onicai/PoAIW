import type { Principal } from '@dfinity/principal';
import type { ActorMethod } from '@dfinity/agent';
import type { IDL } from '@dfinity/candid';

export type ApiError = { 'InvalidId' : null } |
  { 'ZeroAddress' : null } |
  { 'StatusCode' : number } |
  { 'Other' : string };
export interface AuthRecord { 'auth' : string }
export type AuthRecordResult = { 'Ok' : AuthRecord } |
  { 'Err' : ApiError };
export interface CanisterIDRecord { 'canister_id' : string }
export type CanisterIDRecordResult = { 'Ok' : CanisterIDRecord } |
  { 'Err' : ApiError };
export interface ChallengerCtrlbCanister {
  'WhitelistedPrincipals' : ActorMethod<[], Array<Principal>>,
  'add_llm_canister_id' : ActorMethod<
    [CanisterIDRecord],
    StatusCodeRecordResult
  >,
  'amiController' : ActorMethod<[], StatusCodeRecordResult>,
  'amiWhitelisted' : ActorMethod<[], StatusCodeRecordResult>,
  'generateNewChallenge' : ActorMethod<[], GeneratedChallengeResult>,
  'getRoundRobinCanister' : ActorMethod<[], CanisterIDRecordResult>,
  'health' : ActorMethod<[], StatusCodeRecordResult>,
  'isWhitelistLogicOk' : ActorMethod<[], StatusCodeRecordResult>,
  'ready' : ActorMethod<[], StatusCodeRecordResult>,
  'setGameStateCanisterId' : ActorMethod<[string], AuthRecordResult>,
  'setRoundRobinLLMs' : ActorMethod<[bigint], StatusCodeRecordResult>,
  'set_llm_canister_id' : ActorMethod<
    [CanisterIDRecord],
    StatusCodeRecordResult
  >,
  'whitelistPrincipal' : ActorMethod<[Principal], StatusCodeRecordResult>,
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
export interface StatusCodeRecord { 'status_code' : number }
export type StatusCodeRecordResult = { 'Ok' : StatusCodeRecord } |
  { 'Err' : ApiError };
export interface _SERVICE extends ChallengerCtrlbCanister {}
export declare const idlFactory: IDL.InterfaceFactory;
export declare const init: (args: { IDL: typeof IDL }) => IDL.Type[];
