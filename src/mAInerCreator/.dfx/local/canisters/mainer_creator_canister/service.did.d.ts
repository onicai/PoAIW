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
export interface CanisterCreationCanister {
  'amiController' : ActorMethod<[], AuthRecordResult>,
  'createCanister' : ActorMethod<
    [CanisterCreationConfiguration],
    CanisterCreationResult
  >,
  'reset_mainer_canister_wasm' : ActorMethod<[], FileUploadResult>,
  'setMasterCanisterId' : ActorMethod<[string], AuthRecordResult>,
  'testCreateMainerCanister' : ActorMethod<[], CanisterCreationResult>,
  'upload_mainer_canister_wasm_bytes_chunk' : ActorMethod<
    [Uint8Array | number[]],
    FileUploadResult
  >,
  'whoami' : ActorMethod<[], Principal>,
}
export interface CanisterCreationConfiguration {
  'canisterType' : CanisterType,
  'owner' : Principal,
}
export interface CanisterCreationRecord {
  'creationResult' : string,
  'newCanisterId' : string,
}
export type CanisterCreationResult = { 'Ok' : CanisterCreationRecord } |
  { 'Err' : ApiError };
export type CanisterType = { 'Mainer' : null };
export interface FileUploadRecord { 'creationResult' : string }
export type FileUploadResult = { 'Ok' : FileUploadRecord } |
  { 'Err' : ApiError };
export type StatusCode = number;
export interface _SERVICE extends CanisterCreationCanister {}
export declare const idlFactory: IDL.InterfaceFactory;
export declare const init: (args: { IDL: typeof IDL }) => IDL.Type[];
