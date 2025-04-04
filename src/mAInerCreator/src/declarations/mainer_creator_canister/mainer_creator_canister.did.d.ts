import type { Principal } from '@dfinity/principal';
import type { ActorMethod } from '@dfinity/agent';
import type { IDL } from '@dfinity/candid';

export type ApiError = { 'FailedOperation' : null } |
  { 'InvalidId' : null } |
  { 'ZeroAddress' : null } |
  { 'Unauthorized' : null } |
  { 'StatusCode' : StatusCode } |
  { 'Other' : string } |
  { 'InsuffientCycles' : bigint };
export interface AuthRecord { 'auth' : string }
export type AuthRecordResult = { 'Ok' : AuthRecord } |
  { 'Err' : ApiError };
export type AvailableModels = { 'Qwen2_5_500M' : null };
export type CanisterAddress = string;
export interface CanisterCreationCanister {
  'addModelCreationArtefactsEntry' : ActorMethod<
    [AvailableModels, ModelCreationArtefacts],
    InsertArtefactsResult
  >,
  'amiController' : ActorMethod<[], AuthRecordResult>,
  'createCanister' : ActorMethod<
    [CanisterCreationConfiguration],
    CanisterCreationResult
  >,
  'finish_upload_mainer_llm' : ActorMethod<
    [AvailableModels, string],
    FileUploadResult
  >,
  'health' : ActorMethod<[], StatusCodeRecordResult>,
  'setMasterCanisterId' : ActorMethod<[string], AuthRecordResult>,
  'start_upload_mainer_controller_canister_wasm' : ActorMethod<
    [],
    StatusCodeRecordResult
  >,
  'start_upload_mainer_llm' : ActorMethod<[], StatusCodeRecordResult>,
  'start_upload_mainer_llm_canister_wasm' : ActorMethod<
    [AvailableModels],
    StatusCodeRecordResult
  >,
  'testCreateMainerControllerCanister' : ActorMethod<
    [MainerAgentCanisterType, [] | [CanisterAddress]],
    CanisterCreationResult
  >,
  'testCreateMainerLlmCanister' : ActorMethod<[string], CanisterCreationResult>,
  'upload_mainer_controller_canister_wasm_bytes_chunk' : ActorMethod<
    [Uint8Array | number[]],
    FileUploadResult
  >,
  'upload_mainer_llm_bytes_chunk' : ActorMethod<
    [Uint8Array | number[]],
    FileUploadResult
  >,
  'upload_mainer_llm_canister_wasm_bytes_chunk' : ActorMethod<
    [AvailableModels, Uint8Array | number[]],
    FileUploadResult
  >,
  'whoami' : ActorMethod<[], Principal>,
}
export interface CanisterCreationConfiguration {
  'selectedModel' : AvailableModels,
  'canisterType' : ProtocolCanisterType,
  'owner' : Principal,
  'mainerAgentCanisterType' : MainerAgentCanisterType,
  'associatedCanisterAddress' : [] | [CanisterAddress],
}
export interface CanisterCreationRecord {
  'creationResult' : string,
  'newCanisterId' : string,
}
export type CanisterCreationResult = { 'Ok' : CanisterCreationRecord } |
  { 'Err' : ApiError };
export type FileUploadResult = { 'Ok' : UploadResult } |
  { 'Err' : ApiError };
export type InsertArtefactsResult = { 'Ok' : ModelCreationArtefacts } |
  { 'Err' : ApiError };
export type MainerAgentCanisterType = { 'NA' : null } |
  { 'Own' : null } |
  { 'ShareAgent' : null } |
  { 'ShareService' : null };
export interface ModelCreationArtefacts {
  'canisterWasm' : Uint8Array | number[],
  'modelFileSha256' : string,
  'modelFile' : Array<Uint8Array | number[]>,
}
export type ProtocolCanisterType = { 'MainerAgent' : null } |
  { 'MainerLlm' : null } |
  { 'Challenger' : null } |
  { 'Judge' : null } |
  { 'Verifier' : null } |
  { 'MainerCreator' : null };
export type StatusCode = number;
export interface StatusCodeRecord { 'status_code' : StatusCode }
export type StatusCodeRecordResult = { 'Ok' : StatusCodeRecord } |
  { 'Err' : ApiError };
export interface UploadResult { 'creationResult' : string }
export interface _SERVICE extends CanisterCreationCanister {}
export declare const idlFactory: IDL.InterfaceFactory;
export declare const init: (args: { IDL: typeof IDL }) => IDL.Type[];
