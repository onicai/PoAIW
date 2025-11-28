export const idlFactory = ({ IDL }) => {
  const LlmSetupStatus = IDL.Variant({
    'CodeInstallInProgress' : IDL.Null,
    'CanisterCreated' : IDL.Null,
    'ConfigurationInProgress' : IDL.Null,
    'CanisterCreationInProgress' : IDL.Null,
    'ModelUploadProgress' : IDL.Nat8,
  });
  const CanisterStatus = IDL.Variant({
    'Paused' : IDL.Null,
    'Paid' : IDL.Null,
    'Unlocked' : IDL.Null,
    'LlmSetupFinished' : IDL.Null,
    'ControllerCreated' : IDL.Null,
    'LlmSetupInProgress' : LlmSetupStatus,
    'Running' : IDL.Null,
    'Other' : IDL.Text,
    'ControllerCreationInProgress' : IDL.Null,
  });
  const MainerAgentCanisterType = IDL.Variant({
    'NA' : IDL.Null,
    'Own' : IDL.Null,
    'ShareAgent' : IDL.Null,
    'ShareService' : IDL.Null,
  });
  const ProtocolCanisterType = IDL.Variant({
    'MainerAgent' : MainerAgentCanisterType,
    'MainerLlm' : IDL.Null,
    'Challenger' : IDL.Null,
    'Judge' : IDL.Null,
    'Verifier' : IDL.Null,
    'MainerCreator' : IDL.Null,
  });
  const SelectableMainerLLMs = IDL.Variant({ 'Qwen2_5_500M' : IDL.Null });
  const MainerConfigurationInput = IDL.Record({
    'selectedLLM' : IDL.Opt(SelectableMainerLLMs),
    'subnetLlm' : IDL.Text,
    'mainerAgentCanisterType' : MainerAgentCanisterType,
    'cyclesForMainer' : IDL.Nat,
    'subnetCtrl' : IDL.Text,
  });
  const CanisterAddress = IDL.Text;
  const OfficialMainerAgentCanister = IDL.Record({
    'status' : CanisterStatus,
    'canisterType' : ProtocolCanisterType,
    'ownedBy' : IDL.Principal,
    'creationTimestamp' : IDL.Nat64,
    'createdBy' : IDL.Principal,
    'mainerConfig' : MainerConfigurationInput,
    'subnet' : IDL.Text,
    'address' : CanisterAddress,
  });
  const AddControllerToMainerCanisterInput = IDL.Record({
    'newControllerPrincipal' : IDL.Principal,
    'mainerEntry' : OfficialMainerAgentCanister,
  });
  const AddControllerToMainerCanisterRecord = IDL.Record({
    'added' : IDL.Bool,
    'addedControllerPrincipal' : IDL.Principal,
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
  const AddControllerToMainerCanisterResult = IDL.Variant({
    'Ok' : AddControllerToMainerCanisterRecord,
    'Err' : ApiError,
  });
  const ModelCreationArtefacts = IDL.Record({
    'canisterWasm' : IDL.Vec(IDL.Vec(IDL.Nat8)),
    'modelFileSha256' : IDL.Text,
    'modelFile' : IDL.Vec(IDL.Vec(IDL.Nat8)),
  });
  const AddModelCreationArtefactsEntry = IDL.Record({
    'selectedModel' : SelectableMainerLLMs,
    'creationArtefacts' : ModelCreationArtefacts,
  });
  const InsertArtefactsResult = IDL.Variant({
    'Ok' : ModelCreationArtefacts,
    'Err' : ApiError,
  });
  const AuthRecord = IDL.Record({ 'auth' : IDL.Text });
  const AuthRecordResult = IDL.Variant({ 'Ok' : AuthRecord, 'Err' : ApiError });
  const CanisterCreationConfiguration = IDL.Record({
    'associatedCanisterSubnet' : IDL.Text,
    'canisterType' : ProtocolCanisterType,
    'cyclesCreateMainerllmMcMainerllm' : IDL.Nat,
    'owner' : IDL.Principal,
    'mainerConfig' : MainerConfigurationInput,
    'cyclesCreateMainerctrlMcMainerctrl' : IDL.Nat,
    'cyclesCreateMainerllmGsMc' : IDL.Nat,
    'associatedCanisterAddress' : IDL.Opt(CanisterAddress),
    'cyclesCreateMainerctrlGsMc' : IDL.Nat,
    'userMainerEntryCreationTimestamp' : IDL.Nat64,
    'userMainerEntryCanisterType' : ProtocolCanisterType,
  });
  const CanisterCreationRecord = IDL.Record({
    'subnet' : IDL.Text,
    'creationResult' : IDL.Text,
    'newCanisterId' : IDL.Text,
  });
  const CanisterCreationResult = IDL.Variant({
    'Ok' : CanisterCreationRecord,
    'Err' : ApiError,
  });
  const FinishUploadMainerLlmInput = IDL.Record({
    'selectedModel' : SelectableMainerLLMs,
    'modelFileSha256' : IDL.Text,
  });
  const UploadResult = IDL.Record({ 'creationResult' : IDL.Text });
  const FileUploadResult = IDL.Variant({
    'Ok' : UploadResult,
    'Err' : ApiError,
  });
  const CyclesTransaction = IDL.Record({
    'newOfficialCycleBalance' : IDL.Nat,
    'creationTimestamp' : IDL.Nat64,
    'amountAdded' : IDL.Nat,
    'sentBy' : IDL.Principal,
    'previousCyclesBalance' : IDL.Nat,
    'succeeded' : IDL.Bool,
  });
  const CyclesTransactionsResult = IDL.Variant({
    'Ok' : IDL.Vec(CyclesTransaction),
    'Err' : ApiError,
  });
  const StatusCodeRecord = IDL.Record({ 'status_code' : StatusCode });
  const StatusCodeRecordResult = IDL.Variant({
    'Ok' : StatusCodeRecord,
    'Err' : ApiError,
  });
  const ReinstallMainerctrlInput = IDL.Record({
    'associatedCanisterSubnet' : IDL.Text,
    'cyclesReinstallMainerctrlMcMainerctrl' : IDL.Nat,
    'associatedCanisterAddress' : IDL.Opt(CanisterAddress),
    'cyclesReinstallMainerctrlGsMc' : IDL.Nat,
    'mainerAgentEntry' : OfficialMainerAgentCanister,
  });
  const RemoveControllerFromMainerCanisterInput = IDL.Record({
    'toRemoveControllerPrincipal' : IDL.Principal,
    'mainerEntry' : OfficialMainerAgentCanister,
  });
  const RemoveControllerFromMainerCanisterRecord = IDL.Record({
    'removedControllerPrincipal' : IDL.Principal,
    'removed' : IDL.Bool,
  });
  const RemoveControllerFromMainerCanisterResult = IDL.Variant({
    'Ok' : RemoveControllerFromMainerCanisterRecord,
    'Err' : ApiError,
  });
  const AddCyclesRecord = IDL.Record({
    'added' : IDL.Bool,
    'amount' : IDL.Nat,
  });
  const AddCyclesResult = IDL.Variant({
    'Ok' : AddCyclesRecord,
    'Err' : ApiError,
  });
  const SetupCanisterInput = IDL.Record({
    'configurationInput' : CanisterCreationConfiguration,
    'subnet' : IDL.Text,
    'newCanisterId' : IDL.Text,
  });
  const UpgradeMainerctrlInput = IDL.Record({
    'cyclesUpgradeMainerctrlGsMc' : IDL.Nat,
    'associatedCanisterSubnet' : IDL.Text,
    'cyclesUpgradeMainerctrlMcMainerctrl' : IDL.Nat,
    'associatedCanisterAddress' : IDL.Opt(CanisterAddress),
    'mainerAgentEntry' : OfficialMainerAgentCanister,
  });
  const UploadMainerLlmBytesChunkInput = IDL.Record({
    'chunkID' : IDL.Nat,
    'bytesChunk' : IDL.Vec(IDL.Nat8),
  });
  const UploadMainerLlmCanisterWasmBytesChunkInput = IDL.Record({
    'selectedModel' : SelectableMainerLLMs,
    'bytesChunk' : IDL.Vec(IDL.Nat8),
  });
  const MainerCreatorCanister = IDL.Service({
    'addControllerToMainerCanister' : IDL.Func(
        [AddControllerToMainerCanisterInput],
        [AddControllerToMainerCanisterResult],
        [],
      ),
    'addModelCreationArtefactsEntry' : IDL.Func(
        [AddModelCreationArtefactsEntry],
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
        [FinishUploadMainerLlmInput],
        [FileUploadResult],
        [],
      ),
    'getCyclesToSendToGameStateAdmin' : IDL.Func([], [IDL.Nat], ['query']),
    'getCyclesTransactionsAdmin' : IDL.Func(
        [],
        [CyclesTransactionsResult],
        ['query'],
      ),
    'getDefaultSubnetsAdmin' : IDL.Func(
        [],
        [
          IDL.Variant({
            'Ok' : IDL.Vec(IDL.Principal),
            'Err' : IDL.Variant({ 'Unauthorized' : IDL.Null }),
          }),
        ],
        [],
      ),
    'getMinCyclesBalanceAdmin' : IDL.Func([], [IDL.Nat], ['query']),
    'health' : IDL.Func([], [StatusCodeRecordResult], ['query']),
    'isSubnetAvailableAdmin' : IDL.Func(
        [IDL.Text],
        [
          IDL.Variant({
            'Ok' : IDL.Bool,
            'Err' : IDL.Variant({ 'Unauthorized' : IDL.Null }),
          }),
        ],
        [],
      ),
    'reinstallMainerctrl' : IDL.Func(
        [ReinstallMainerctrlInput],
        [StatusCodeRecordResult],
        [],
      ),
    'removeControllerFromMainerCanister' : IDL.Func(
        [RemoveControllerFromMainerCanisterInput],
        [RemoveControllerFromMainerCanisterResult],
        [],
      ),
    'sendCyclesToGameStateCanister' : IDL.Func([], [AddCyclesResult], []),
    'setCyclesToSendToGameStateAdmin' : IDL.Func(
        [IDL.Nat],
        [StatusCodeRecordResult],
        [],
      ),
    'setMasterCanisterId' : IDL.Func([IDL.Text], [AuthRecordResult], []),
    'setMinCyclesBalanceAdmin' : IDL.Func(
        [IDL.Nat],
        [StatusCodeRecordResult],
        [],
      ),
    'setupCanister' : IDL.Func(
        [SetupCanisterInput],
        [CanisterCreationResult],
        [],
      ),
    'start_upload_mainer_controller_canister_wasm' : IDL.Func(
        [],
        [StatusCodeRecordResult],
        [],
      ),
    'start_upload_mainer_llm' : IDL.Func([], [StatusCodeRecordResult], []),
    'start_upload_mainer_llm_canister_wasm' : IDL.Func(
        [SelectableMainerLLMs],
        [StatusCodeRecordResult],
        [],
      ),
    'upgradeMainerctrl' : IDL.Func(
        [UpgradeMainerctrlInput],
        [StatusCodeRecordResult],
        [],
      ),
    'upload_mainer_controller_canister_wasm_bytes_chunk' : IDL.Func(
        [IDL.Vec(IDL.Nat8)],
        [FileUploadResult],
        [],
      ),
    'upload_mainer_llm_bytes_chunk' : IDL.Func(
        [UploadMainerLlmBytesChunkInput],
        [FileUploadResult],
        [],
      ),
    'upload_mainer_llm_canister_wasm_bytes_chunk' : IDL.Func(
        [UploadMainerLlmCanisterWasmBytesChunkInput],
        [FileUploadResult],
        [],
      ),
    'whoami' : IDL.Func([], [IDL.Principal], ['query']),
  });
  return MainerCreatorCanister;
};
export const init = ({ IDL }) => { return []; };
