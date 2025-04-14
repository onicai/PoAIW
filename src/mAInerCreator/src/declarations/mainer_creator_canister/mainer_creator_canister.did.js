export const idlFactory = ({ IDL }) => {
  const AvailableModels = IDL.Variant({ 'Qwen2_5_500M' : IDL.Null });
  const ModelCreationArtefacts = IDL.Record({
    'canisterWasm' : IDL.Vec(IDL.Nat8),
    'modelFileSha256' : IDL.Text,
    'modelFile' : IDL.Vec(IDL.Vec(IDL.Nat8)),
  });
  const StatusCode = IDL.Nat16;
  const ApiError = IDL.Variant({
    'FailedOperation' : IDL.Null,
    'InvalidId' : IDL.Null,
    'ZeroAddress' : IDL.Null,
    'Unauthorized' : IDL.Null,
    'StatusCode' : StatusCode,
    'Other' : IDL.Text,
    'InsuffientCycles' : IDL.Nat,
  });
  const InsertArtefactsResult = IDL.Variant({
    'Ok' : ModelCreationArtefacts,
    'Err' : ApiError,
  });
  const AuthRecord = IDL.Record({ 'auth' : IDL.Text });
  const AuthRecordResult = IDL.Variant({ 'Ok' : AuthRecord, 'Err' : ApiError });
  const ProtocolCanisterType = IDL.Variant({
    'MainerAgent' : IDL.Null,
    'MainerLlm' : IDL.Null,
    'Challenger' : IDL.Null,
    'Judge' : IDL.Null,
    'Verifier' : IDL.Null,
    'MainerCreator' : IDL.Null,
  });
  const MainerAgentCanisterType = IDL.Variant({
    'NA' : IDL.Null,
    'Own' : IDL.Null,
    'ShareAgent' : IDL.Null,
    'ShareService' : IDL.Null,
  });
  const CanisterAddress = IDL.Text;
  const CanisterCreationConfiguration = IDL.Record({
    'selectedModel' : AvailableModels,
    'canisterType' : ProtocolCanisterType,
    'owner' : IDL.Principal,
    'mainerAgentCanisterType' : MainerAgentCanisterType,
    'associatedCanisterAddress' : IDL.Opt(CanisterAddress),
  });
  const CanisterCreationRecord = IDL.Record({
    'creationResult' : IDL.Text,
    'newCanisterId' : IDL.Text,
  });
  const CanisterCreationResult = IDL.Variant({
    'Ok' : CanisterCreationRecord,
    'Err' : ApiError,
  });
  const UploadResult = IDL.Record({ 'creationResult' : IDL.Text });
  const FileUploadResult = IDL.Variant({
    'Ok' : UploadResult,
    'Err' : ApiError,
  });
  const StatusCodeRecord = IDL.Record({ 'status_code' : StatusCode });
  const StatusCodeRecordResult = IDL.Variant({
    'Ok' : StatusCodeRecord,
    'Err' : ApiError,
  });
  const CanisterCreationCanister = IDL.Service({
    'addModelCreationArtefactsEntry' : IDL.Func(
        [AvailableModels, ModelCreationArtefacts],
        [InsertArtefactsResult],
        [],
      ),
    'amiController' : IDL.Func([], [AuthRecordResult], ['query']),
    'createCanister' : IDL.Func(
        [CanisterCreationConfiguration],
        [CanisterCreationResult],
        [],
      ),
    'finish_upload_mainer_llm' : IDL.Func(
        [AvailableModels, IDL.Text],
        [FileUploadResult],
        [],
      ),
    'health' : IDL.Func([], [StatusCodeRecordResult], ['query']),
    'setMasterCanisterId' : IDL.Func([IDL.Text], [AuthRecordResult], []),
    'start_upload_mainer_controller_canister_wasm' : IDL.Func(
        [],
        [StatusCodeRecordResult],
        [],
      ),
    'start_upload_mainer_llm' : IDL.Func([], [StatusCodeRecordResult], []),
    'start_upload_mainer_llm_canister_wasm' : IDL.Func(
        [AvailableModels],
        [StatusCodeRecordResult],
        [],
      ),
    'testCreateMainerControllerCanister' : IDL.Func(
        [MainerAgentCanisterType, IDL.Opt(CanisterAddress)],
        [CanisterCreationResult],
        [],
      ),
    'testCreateMainerLlmCanister' : IDL.Func(
        [IDL.Text],
        [CanisterCreationResult],
        [],
      ),
    'upload_mainer_controller_canister_wasm_bytes_chunk' : IDL.Func(
        [IDL.Vec(IDL.Nat8)],
        [FileUploadResult],
        [],
      ),
    'upload_mainer_llm_bytes_chunk' : IDL.Func(
        [IDL.Vec(IDL.Nat8), IDL.Nat],
        [FileUploadResult],
        [],
      ),
    'upload_mainer_llm_canister_wasm_bytes_chunk' : IDL.Func(
        [AvailableModels, IDL.Vec(IDL.Nat8)],
        [FileUploadResult],
        [],
      ),
    'whoami' : IDL.Func([], [IDL.Principal], ['query']),
  });
  return CanisterCreationCanister;
};
export const init = ({ IDL }) => { return []; };
