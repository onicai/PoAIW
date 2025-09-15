import type { Principal } from '@dfinity/principal';
import type { ActorMethod } from '@dfinity/agent';
import type { IDL } from '@dfinity/candid';

export interface ApiCanister {
  'amiController' : ActorMethod<[], AuthRecordResult>,
  'bulkCreateDailyMetricsAdmin' : ActorMethod<
    [Array<DailyMetricInput>],
    BulkCreateResult
  >,
  'createDailyMetricAdmin' : ActorMethod<[DailyMetricInput], DailyMetricResult>,
  'deleteDailyMetricAdmin' : ActorMethod<[string], DailyMetricOperationResult>,
  'getDailyMetricByDate' : ActorMethod<[string], DailyMetricResult>,
  'getDailyMetrics' : ActorMethod<
    [[] | [DailyMetricsQuery]],
    DailyMetricsResult
  >,
  'getDailyMetricsAdmin' : ActorMethod<[], DailyMetricsResult>,
  'getLatestDailyMetric' : ActorMethod<[], DailyMetricResult>,
  'getMasterCanisterId' : ActorMethod<[], AuthRecordResult>,
  'getNumDailyMetrics' : ActorMethod<[], NatResult>,
  'health' : ActorMethod<[], StatusCodeRecordResult>,
  'setMasterCanisterId' : ActorMethod<[string], AuthRecordResult>,
  'updateDailyMetricAdmin' : ActorMethod<
    [string, DailyMetricUpdateInput],
    DailyMetricResult
  >,
  'whoami' : ActorMethod<[], Principal>,
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
export type BulkCreateResult = { 'Ok' : bigint } |
  { 'Err' : ApiError };
export interface DailyBurnRate { 'usd' : number, 'cycles' : bigint }
export interface DailyMetric {
  'derived_metrics' : DerivedMetrics,
  'mainers' : MainersMetrics,
  'metadata' : DailyMetricMetadata,
  'system_metrics' : SystemMetrics,
}
export interface DailyMetricInput {
  'total_paused_mainers' : bigint,
  'date' : string,
  'paused_very_high_burn_rate_mainers' : bigint,
  'paused_medium_burn_rate_mainers' : bigint,
  'total_cycles_all_mainers' : bigint,
  'active_very_high_burn_rate_mainers' : bigint,
  'active_high_burn_rate_mainers' : bigint,
  'active_low_burn_rate_mainers' : bigint,
  'paused_low_burn_rate_mainers' : bigint,
  'daily_burn_rate_usd' : number,
  'paused_high_burn_rate_mainers' : bigint,
  'total_active_mainers' : bigint,
  'active_medium_burn_rate_mainers' : bigint,
  'daily_burn_rate_cycles' : bigint,
  'funnai_index' : number,
  'total_mainers_created' : bigint,
}
export interface DailyMetricMetadata {
  'updated_at' : string,
  'date' : string,
  'created_at' : string,
}
export type DailyMetricOperationResult = { 'Ok' : boolean } |
  { 'Err' : ApiError };
export type DailyMetricResult = { 'Ok' : DailyMetric } |
  { 'Err' : ApiError };
export interface DailyMetricUpdateInput {
  'total_paused_mainers' : [] | [bigint],
  'paused_very_high_burn_rate_mainers' : [] | [bigint],
  'paused_medium_burn_rate_mainers' : [] | [bigint],
  'total_cycles_all_mainers' : [] | [bigint],
  'active_very_high_burn_rate_mainers' : [] | [bigint],
  'active_high_burn_rate_mainers' : [] | [bigint],
  'active_low_burn_rate_mainers' : [] | [bigint],
  'paused_low_burn_rate_mainers' : [] | [bigint],
  'daily_burn_rate_usd' : [] | [number],
  'paused_high_burn_rate_mainers' : [] | [bigint],
  'total_active_mainers' : [] | [bigint],
  'active_medium_burn_rate_mainers' : [] | [bigint],
  'daily_burn_rate_cycles' : [] | [bigint],
  'funnai_index' : [] | [number],
  'total_mainers_created' : [] | [bigint],
}
export interface DailyMetricsQuery {
  'end_date' : [] | [string],
  'limit' : [] | [bigint],
  'start_date' : [] | [string],
}
export interface DailyMetricsResponse {
  'period' : PeriodInfo,
  'daily_metrics' : Array<DailyMetric>,
}
export type DailyMetricsResult = { 'Ok' : DailyMetricsResponse } |
  { 'Err' : ApiError };
export interface DerivedMetrics {
  'avg_cycles_per_mainer' : number,
  'paused_percentage' : number,
  'tier_distribution' : {
    'low' : number,
    'high' : number,
    'very_high' : number,
    'medium' : number,
  },
  'burn_rate_per_active_mainer' : number,
  'active_percentage' : number,
}
export interface MainersMetrics {
  'totals' : {
    'created' : bigint,
    'active' : bigint,
    'total_cycles' : bigint,
    'paused' : bigint,
  },
  'breakdown_by_tier' : {
    'active' : MainersTierBreakdown,
    'paused' : MainersTierBreakdown,
  },
}
export interface MainersTierBreakdown {
  'low' : bigint,
  'high' : bigint,
  'very_high' : bigint,
  'medium' : bigint,
}
export type NatResult = { 'Ok' : bigint } |
  { 'Err' : ApiError };
export interface PeriodInfo {
  'end_date' : string,
  'total_days' : bigint,
  'start_date' : string,
}
export type StatusCode = number;
export interface StatusCodeRecord { 'status_code' : StatusCode }
export type StatusCodeRecordResult = { 'Ok' : StatusCodeRecord } |
  { 'Err' : ApiError };
export interface SystemMetrics {
  'funnai_index' : number,
  'daily_burn_rate' : DailyBurnRate,
}
export interface _SERVICE extends ApiCanister {}
export declare const idlFactory: IDL.InterfaceFactory;
export declare const init: (args: { IDL: typeof IDL }) => IDL.Type[];
