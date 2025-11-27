import type { Principal } from '@dfinity/principal';
import type { ActorMethod } from '@dfinity/agent';
import type { IDL } from '@dfinity/candid';

export interface AddCyclesRecord { 'added' : boolean, 'amount' : bigint }
export type AddCyclesResult = { 'Ok' : AddCyclesRecord } |
  { 'Err' : ApiError };
export interface AddModelCreationArtefactsEntry {
  'selectedModel' : SelectableMainerLLMs,
  'creationArtefacts' : ModelCreationArtefacts,
}
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
export type CanisterAddress = string;
export interface CanisterCreationConfiguration {
  'associatedCanisterSubnet' : string,
  'canisterType' : ProtocolCanisterType,
  'cyclesCreateMainerllmMcMainerllm' : bigint,
  'owner' : Principal,
  'mainerConfig' : MainerConfigurationInput,
  'cyclesCreateMainerctrlMcMainerctrl' : bigint,
  'cyclesCreateMainerllmGsMc' : bigint,
  'associatedCanisterAddress' : [] | [CanisterAddress],
  'cyclesCreateMainerctrlGsMc' : bigint,
  'userMainerEntryCreationTimestamp' : bigint,
  'userMainerEntryCanisterType' : ProtocolCanisterType,
}
export interface CanisterCreationRecord {
  'subnet' : string,
  'creationResult' : string,
  'newCanisterId' : string,
}
export type CanisterCreationResult = { 'Ok' : CanisterCreationRecord } |
  { 'Err' : ApiError };
export type CanisterStatus = { 'Paused' : null } |
  { 'Paid' : null } |
  { 'Unlocked' : null } |
  { 'LlmSetupFinished' : null } |
  { 'ControllerCreated' : null } |
  { 'LlmSetupInProgress' : LlmSetupStatus } |
  { 'Running' : null } |
  { 'Other' : string } |
  { 'ControllerCreationInProgress' : null };
export interface CyclesTransaction {
  'newOfficialCycleBalance' : bigint,
  'creationTimestamp' : bigint,
  'amountAdded' : bigint,
  'sentBy' : Principal,
  'previousCyclesBalance' : bigint,
  'succeeded' : boolean,
}
export type CyclesTransactionsResult = { 'Ok' : Array<CyclesTransaction> } |
  { 'Err' : ApiError };
export type FileUploadResult = { 'Ok' : UploadResult } |
  { 'Err' : ApiError };
export interface FinishUploadMainerLlmInput {
  'selectedModel' : SelectableMainerLLMs,
  'modelFileSha256' : string,
}
export type InsertArtefactsResult = { 'Ok' : ModelCreationArtefacts } |
  { 'Err' : ApiError };
export type LlmSetupStatus = { 'CodeInstallInProgress' : null } |
  { 'CanisterCreated' : null } |
  { 'ConfigurationInProgress' : null } |
  { 'CanisterCreationInProgress' : null } |
  { 'ModelUploadProgress' : number };
export type MainerAgentCanisterType = { 'NA' : null } |
  { 'Own' : null } |
  { 'ShareAgent' : null } |
  { 'ShareService' : null };
export interface MainerConfigurationInput {
  'selectedLLM' : [] | [SelectableMainerLLMs],
  'subnetLlm' : string,
  'mainerAgentCanisterType' : MainerAgentCanisterType,
  'cyclesForMainer' : bigint,
  'subnetCtrl' : string,
}
export interface MainerCreatorCanister {
  'addModelCreationArtefactsEntry' : ActorMethod<
    [AddModelCreationArtefactsEntry],
    InsertArtefactsResult
  >,
  'amiController' : ActorMethod<[], AuthRecordResult>,
  'createCanister' : ActorMethod<
    [CanisterCreationConfiguration],
    CanisterCreationResult
  >,
  'finish_upload_mainer_controller_canister_wasm' : ActorMethod<
    [],
    StatusCodeRecordResult
  >,
  'finish_upload_mainer_llm' : ActorMethod<
    [FinishUploadMainerLlmInput],
    FileUploadResult
  >,
  'finish_upload_mainer_llm_canister_wasm' : ActorMethod<
    [SelectableMainerLLMs],
    StatusCodeRecordResult
  >,
  'getCyclesToSendToGameStateAdmin' : ActorMethod<[], bigint>,
  'getCyclesTransactionsAdmin' : ActorMethod<[], CyclesTransactionsResult>,
  'getDefaultSubnetsAdmin' : ActorMethod<
    [],
    { 'Ok' : Array<Principal> } |
      { 'Err' : { 'Unauthorized' : null } }
  >,
  'getMasterCanisterIdAdmin' : ActorMethod<[], string>,
  'getMinCyclesBalanceAdmin' : ActorMethod<[], bigint>,
  'getSha256HashesAdmin' : ActorMethod<[], Sha256HashesResult>,
  'health' : ActorMethod<[], StatusCodeRecordResult>,
  'isSubnetAvailableAdmin' : ActorMethod<
    [string],
    { 'Ok' : boolean } |
      { 'Err' : { 'Unauthorized' : null } }
  >,
  'reinstallMainerctrl' : ActorMethod<
    [ReinstallMainerctrlInput],
    StatusCodeRecordResult
  >,
  'sendCyclesToGameStateCanister' : ActorMethod<[], AddCyclesResult>,
  'setCyclesToSendToGameStateAdmin' : ActorMethod<
    [bigint],
    StatusCodeRecordResult
  >,
  'setMasterCanisterId' : ActorMethod<[string], AuthRecordResult>,
  'setMinCyclesBalanceAdmin' : ActorMethod<[bigint], StatusCodeRecordResult>,
  'setupCanister' : ActorMethod<[SetupCanisterInput], CanisterCreationResult>,
  'start_upload_mainer_controller_canister_wasm' : ActorMethod<
    [],
    StatusCodeRecordResult
  >,
  'start_upload_mainer_llm' : ActorMethod<[], StatusCodeRecordResult>,
  'start_upload_mainer_llm_canister_wasm' : ActorMethod<
    [SelectableMainerLLMs],
    StatusCodeRecordResult
  >,
  'upgradeMainerctrl' : ActorMethod<
    [UpgradeMainerctrlInput],
    StatusCodeRecordResult
  >,
  'upload_mainer_controller_canister_wasm_bytes_chunk' : ActorMethod<
    [Uint8Array | number[]],
    FileUploadResult
  >,
  'upload_mainer_llm_bytes_chunk' : ActorMethod<
    [UploadMainerLlmBytesChunkInput],
    FileUploadResult
  >,
  'upload_mainer_llm_canister_wasm_bytes_chunk' : ActorMethod<
    [UploadMainerLlmCanisterWasmBytesChunkInput],
    FileUploadResult
  >,
  'whoami' : ActorMethod<[], Principal>,
}
export interface ModelCreationArtefacts {
  'canisterWasm' : Array<Uint8Array | number[]>,
  'modelFileSha256' : string,
  'modelFile' : Array<Uint8Array | number[]>,
}
export interface OfficialMainerAgentCanister {
  'status' : CanisterStatus,
  'canisterType' : ProtocolCanisterType,
  'ownedBy' : Principal,
  'creationTimestamp' : bigint,
  'createdBy' : Principal,
  'mainerConfig' : MainerConfigurationInput,
  'subnet' : string,
  'address' : CanisterAddress,
}
export type ProtocolCanisterType = { 'MainerAgent' : MainerAgentCanisterType } |
  { 'MainerLlm' : null } |
  { 'Challenger' : null } |
  { 'Judge' : null } |
  { 'Verifier' : null } |
  { 'MainerCreator' : null };
export interface ReinstallMainerctrlInput {
  'associatedCanisterSubnet' : string,
  'cyclesReinstallMainerctrlMcMainerctrl' : bigint,
  'associatedCanisterAddress' : [] | [CanisterAddress],
  'cyclesReinstallMainerctrlGsMc' : bigint,
  'mainerAgentEntry' : OfficialMainerAgentCanister,
}
export type SelectableMainerLLMs = { 'Qwen2_5_500M' : null };
export interface SetupCanisterInput {
  'configurationInput' : CanisterCreationConfiguration,
  'subnet' : string,
  'newCanisterId' : string,
}
export interface Sha256HashesRecord {
  'llmWasmHashes' : Array<
    [string, { 'wasmSha256' : string, 'modelFileSha256' : string }]
  >,
  'mainerControllerWasmSha256' : string,
}
export type Sha256HashesResult = { 'Ok' : Sha256HashesRecord } |
  { 'Err' : ApiError };
export type StatusCode = number;
export interface StatusCodeRecord { 'status_code' : StatusCode }
export type StatusCodeRecordResult = { 'Ok' : StatusCodeRecord } |
  { 'Err' : ApiError };
export interface UpgradeMainerctrlInput {
  'cyclesUpgradeMainerctrlGsMc' : bigint,
  'associatedCanisterSubnet' : string,
  'cyclesUpgradeMainerctrlMcMainerctrl' : bigint,
  'associatedCanisterAddress' : [] | [CanisterAddress],
  'mainerAgentEntry' : OfficialMainerAgentCanister,
}
export interface UploadMainerLlmBytesChunkInput {
  'chunkID' : bigint,
  'bytesChunk' : Uint8Array | number[],
}
export interface UploadMainerLlmCanisterWasmBytesChunkInput {
  'selectedModel' : SelectableMainerLLMs,
  'bytesChunk' : Uint8Array | number[],
}
export interface UploadResult { 'creationResult' : string }
export interface _SERVICE extends MainerCreatorCanister {}
export declare const idlFactory: IDL.InterfaceFactory;
export declare const init: (args: { IDL: typeof IDL }) => IDL.Type[];
