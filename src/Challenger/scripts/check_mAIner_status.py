#!/usr/bin/env python3

import argparse
import os
import json
import subprocess
import time
import threading
from datetime import datetime
from concurrent.futures import ThreadPoolExecutor, as_completed
from typing import Optional

from .get_mainers import get_mainers, get_mainer_is_active, get_mainer_setting
from .get_mainers_health import (
    is_transient_error,
    run_command_with_retry,
    log_message,
)

# Get the directory of this script
SCRIPT_DIR = os.path.dirname(os.path.realpath(__file__))

# Status constants
STATUS_HEALTHY = "Healthy"
STATUS_MAINTENANCE = "Maintenance"
STATUS_STOPPED = "Stopped"
STATUS_FROZEN = "Frozen"
STATUS_UNINSTALLED = "Uninstalled"
STATUS_UNAVAILABLE = "Unavailable"

# Error indicators
FROZEN_INDICATORS = ["IC0207", "is out of cycles", "frozen"]
STOPPED_INDICATORS = ["IC0508"]

# Health success patterns (from get_mainers_health.py)
HEALTH_OK_PATTERNS = [
    "(variant { Ok = record { status_code = 200 : nat16 } })",
    "(variant { 17_724 = record { 3_475_804_314 = 200 : nat16 } })",
]


def is_frozen_error(error_text: str) -> bool:
    """Check if an error indicates the canister is frozen."""
    if not error_text:
        return False
    return any(indicator in error_text for indicator in FROZEN_INDICATORS)


def is_stopped_error(error_text: str) -> bool:
    """Check if an error indicates the canister is stopped."""
    if not error_text:
        return False
    return any(indicator in error_text for indicator in STOPPED_INDICATORS)


def collect_error_text(e) -> str:
    """Collect meaningful error text from a subprocess exception.

    Prefers stderr/stdout over the generic str(e) which contains the raw command.
    """
    parts = []
    if hasattr(e, 'stderr') and e.stderr:
        parts.append(e.stderr.strip())
    if hasattr(e, 'stdout') and e.stdout:
        parts.append(e.stdout.strip())
    if parts:
        return " ".join(parts).replace("\n", " ")
    return str(e).replace("\n", " ")


def get_module_hash(network: str, canister_id: str) -> tuple[Optional[str], Optional[str]]:
    """Get the module hash of a canister via dfx canister info.

    Retries on transient errors (timeouts, connection issues).

    Returns:
        (module_hash, error_message)
        - ("0xabc...", None) if hash found
        - ("None", None) if canister is uninstalled
        - (None, "error text") if call failed
    """
    cmd = ["icp", "canister", "status", canister_id, "-e", network, "-p"]
    max_retries = 3
    retry_delay = 5.0

    for attempt in range(1, max_retries + 1):
        try:
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=30, check=True)
            for line in result.stdout.split('\n'):
                if 'Module hash:' in line:
                    hash_value = line.split(':', 1)[1].strip()
                    return (hash_value, None)
            return (None, "Module hash line not found in output")
        except (subprocess.CalledProcessError, subprocess.TimeoutExpired) as e:
            error_text = collect_error_text(e)

            # Don't retry deterministic errors (frozen, out of cycles)
            if is_frozen_error(error_text):
                return (None, error_text)

            # Retry on transient errors
            if attempt < max_retries and is_transient_error(error_text):
                delay = retry_delay * (2 ** (attempt - 1))
                time.sleep(delay)
                continue

            return (None, error_text)

    return (None, "Max retries exceeded")


def check_health(network: str, canister_id: str) -> tuple[str, Optional[str]]:
    """Call the health endpoint on a canister with retries for transient errors.

    Returns:
        (status, error_message)
    """
    cmd = ["icp", "canister", "call", canister_id, "health", "()", "--query", "-e", network]
    max_retries = 3
    retry_delay = 5.0

    for attempt in range(1, max_retries + 1):
        try:
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=30, check=True)
            output = result.stdout.strip()
            if any(pattern in output for pattern in HEALTH_OK_PATTERNS):
                return (STATUS_HEALTHY, None)
            else:
                return (STATUS_MAINTENANCE, f"health returned: {output[:150]}")
        except (subprocess.CalledProcessError, subprocess.TimeoutExpired) as e:
            error_text = collect_error_text(e)

            if is_frozen_error(error_text):
                return (STATUS_FROZEN, error_text)

            if is_stopped_error(error_text):
                return (STATUS_STOPPED, error_text)

            # Retry on transient errors
            if attempt < max_retries and is_transient_error(error_text):
                delay = retry_delay * (2 ** (attempt - 1))
                time.sleep(delay)
                continue

            return (STATUS_UNAVAILABLE, error_text)

    return (STATUS_UNAVAILABLE, "Max retries exceeded")


def calculate_freeze_prediction(memory_bytes, cycles_balance):
    """Calculate freeze prediction based on memory idle cost.

    Returns:
        (daily_drain, freeze_threshold, days_until_freeze) or (None, None, None)
    """
    if memory_bytes is None or cycles_balance is None or memory_bytes == 0:
        return (None, None, None)
    # 317,500 cycles per GiB per second on 13-node subnets
    # (was 127,000, increased 2.5x by NNS Proposal 140538 / Mission70)
    # Verified: dfx canister status shows idle_cycles_burned_per_day = 10.6B for 416MB,
    # which matches 317,500 rate (127,000 rate would give only 4.3B)
    daily_drain = int(memory_bytes * 317_500 / (1024 ** 3) * 86_400)
    freeze_threshold = daily_drain * 30  # 30 days = default freezing threshold
    if daily_drain > 0:
        days_until_freeze = round((cycles_balance - freeze_threshold) / daily_drain, 1)
    else:
        days_until_freeze = None
    return (daily_drain, freeze_threshold, days_until_freeze)


def get_canister_resources(network: str, canister_id: str) -> tuple[Optional[int], Optional[int]]:
    """Get memory size and cycle balance via dfx canister status.

    Retries on transient errors. Returns (None, None) for frozen/unreachable.

    Returns:
        (memory_bytes, cycles_balance)
    """
    cmd = ["icp", "canister", "status", canister_id, "-e", network]
    max_retries = 3
    retry_delay = 5.0

    for attempt in range(1, max_retries + 1):
        try:
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=30, check=True)
            memory = None
            balance = None
            for line in result.stdout.split('\n'):
                if line.strip().startswith('Memory Size:'):
                    memory = int(line.split(':')[1].strip().split()[0])
                elif line.strip().startswith('Balance:'):
                    balance = int(line.split(':')[1].strip().split()[0])
            return (memory, balance)
        except (subprocess.CalledProcessError, subprocess.TimeoutExpired) as e:
            error_text = collect_error_text(e)
            if is_frozen_error(error_text):
                return (None, None)
            if attempt < max_retries and is_transient_error(error_text):
                delay = retry_delay * (2 ** (attempt - 1))
                time.sleep(delay)
                continue
            return (None, None)

    return (None, None)


def check_canister_status(network: str, canister_id: str, owner: str,
                          index: int, total: int) -> dict:
    """Check the full status of a single mAIner canister.

    Detection order:
    1. dfx canister info → check Module hash (uninstalled/frozen)
    2. health endpoint → healthy/maintenance/stopped/frozen/unavailable
    """
    result = {
        "canister_id": canister_id,
        "owner": owner,
        "status": STATUS_UNAVAILABLE,
        "module_hash": "",
        "error_message": "",
        "active": None,
        "burn_rate": "",
        "memory_bytes": None,
        "cycles_balance": None,
        "daily_drain": None,
        "freeze_threshold": None,
        "days_until_freeze": None,
    }

    # Step 1: Check module hash via dfx canister info
    module_hash, info_error = get_module_hash(network, canister_id)

    if info_error:
        # info call failed — check if frozen
        if is_frozen_error(info_error):
            result["status"] = STATUS_FROZEN
            result["error_message"] = info_error
            log_message(f"{canister_id} — {STATUS_FROZEN}", "ERROR", index, total)
            return result
        # Unknown error on info call — mark unavailable
        result["status"] = STATUS_UNAVAILABLE
        result["error_message"] = info_error
        log_message(f"{canister_id} — {STATUS_UNAVAILABLE}", "ERROR", index, total)
        return result

    result["module_hash"] = module_hash

    if module_hash == "None":
        result["status"] = STATUS_UNINSTALLED
        log_message(f"{canister_id} — {STATUS_UNINSTALLED}", "ERROR", index, total)
        return result

    # Step 2: Check health endpoint
    status, health_error = check_health(network, canister_id)
    result["status"] = status
    if health_error:
        result["error_message"] = health_error

    if status != STATUS_HEALTHY:
        log_message(f"{canister_id} — {status}", "ERROR", index, total)
        return result

    # Step 3: For Healthy canisters, check active/paused and burn rate
    is_active = get_mainer_is_active(network, canister_id)
    result["active"] = is_active

    if is_active:
        result["burn_rate"] = get_mainer_setting(network, canister_id)

    # Step 4: Get memory and cycle balance for Healthy canisters
    memory, balance = get_canister_resources(network, canister_id)
    result["memory_bytes"] = memory
    result["cycles_balance"] = balance

    # Step 5: Calculate freeze prediction
    daily_drain, freeze_thresh, days_left = calculate_freeze_prediction(memory, balance)
    result["daily_drain"] = daily_drain
    result["freeze_threshold"] = freeze_thresh
    result["days_until_freeze"] = days_left

    mem_mb = f"{memory / 1_000_000:.1f}MB" if memory else "?"
    bal_t = f"{balance / 1_000_000_000_000:.2f}T" if balance else "?"
    days_str = f"{days_left}d" if days_left is not None else "?"

    if is_active:
        log_message(f"{canister_id} — {STATUS_HEALTHY} (Active, {result['burn_rate']}, {mem_mb}, {bal_t}, {days_str})", "SUCCESS", index, total)
    elif is_active is False:
        log_message(f"{canister_id} — {STATUS_HEALTHY} (Paused, {mem_mb}, {bal_t}, {days_str})", "SUCCESS", index, total)
    else:
        log_message(f"{canister_id} — {STATUS_HEALTHY} (unknown, {mem_mb}, {bal_t}, {days_str})", "SUCCESS", index, total)

    return result


def filter_share_agents(mainers: list) -> list:
    """Filter mAIner list to only ShareAgent type with non-empty addresses."""
    share_agents = []
    for mainer in mainers:
        address = mainer.get('address', '')
        canister_type_dict = mainer.get('canisterType', {}).get("MainerAgent", {})
        canister_type = list(canister_type_dict.keys())[0] if canister_type_dict else ''

        if canister_type == "ShareAgent" and address != "":
            share_agents.append({
                "address": address,
                "owner": mainer.get('ownedBy', 'Unknown'),
            })
    return share_agents


def write_markdown_report(results: dict, md_path: str) -> None:
    """Write a human-readable markdown report with aligned tables."""
    summary = results["summary"]
    mainers = results["mainers"]
    timestamp = results["timestamp"]
    network = results["network"]

    lines = []
    lines.append(f"# mAIner Status Report — {network} — {timestamp}")
    lines.append("")
    lines.append("## Summary")
    lines.append("")
    lines.append("| Status             | Count |")
    lines.append("|--------------------|-------|")
    for status in [STATUS_HEALTHY, STATUS_MAINTENANCE, STATUS_STOPPED,
                   STATUS_FROZEN, STATUS_UNINSTALLED, STATUS_UNAVAILABLE]:
        key = status.lower()
        count = summary.get(key, 0)
        lines.append(f"| {status:<18} | {count:>5} |")
    lines.append(f"| **Total**          | **{summary['total_share_agents']:>3}** |")
    lines.append("")
    if summary.get("healthy", 0) > 0:
        lines.append("### Healthy Breakdown")
        lines.append("")
        lines.append("| Detail             | Count |")
        lines.append("|--------------------|-------|")
        lines.append(f"| Active             | {summary.get('active', 0):>5} |")
        lines.append(f"| Paused             | {summary.get('paused', 0):>5} |")
        lines.append(f"| Burn Rate: Low     | {summary.get('burn_rate_low', 0):>5} |")
        lines.append(f"| Burn Rate: Medium  | {summary.get('burn_rate_medium', 0):>5} |")
        lines.append(f"| Burn Rate: High    | {summary.get('burn_rate_high', 0):>5} |")
        lines.append(f"| Burn Rate: VeryHigh| {summary.get('burn_rate_very_high', 0):>5} |")
        if summary.get("burn_rate_other", 0) > 0:
            lines.append(f"| Burn Rate: Other   | {summary.get('burn_rate_other', 0):>5} |")
    lines.append("")

    # Memory and cycles stats for healthy canisters
    healthy_with_mem = [m for m in mainers if m["status"] == STATUS_HEALTHY and m.get("memory_bytes") is not None]
    if healthy_with_mem:
        mem_values = [m["memory_bytes"] for m in healthy_with_mem]
        avg_mem = sum(mem_values) / len(mem_values) / 1_000_000
        max_mem = max(mem_values) / 1_000_000
        min_mem = min(mem_values) / 1_000_000
        lines.append("### Memory & Cycles (Healthy mAIners)")
        lines.append("")
        lines.append(f"| Metric              | Value       |")
        lines.append(f"|---------------------|-------------|")
        lines.append(f"| Avg Memory          | {avg_mem:>8.1f} MB |")
        lines.append(f"| Min Memory          | {min_mem:>8.1f} MB |")
        lines.append(f"| Max Memory          | {max_mem:>8.1f} MB |")
        healthy_with_bal = [m for m in healthy_with_mem if m.get("cycles_balance") is not None]
        if healthy_with_bal:
            bal_values = [m["cycles_balance"] for m in healthy_with_bal]
            avg_bal = sum(bal_values) / len(bal_values) / 1_000_000_000_000
            min_bal = min(bal_values) / 1_000_000_000_000
            max_bal = max(bal_values) / 1_000_000_000_000
            lines.append(f"| Avg Cycles Balance  | {avg_bal:>8.2f} T  |")
            lines.append(f"| Min Cycles Balance  | {min_bal:>8.2f} T  |")
            lines.append(f"| Max Cycles Balance  | {max_bal:>8.2f} T  |")
        lines.append("")
        # At-risk section
        lines.append("### Freeze Risk (Healthy mAIners)")
        lines.append("")
        lines.append("| Risk Window          | Count |")
        lines.append("|----------------------|-------|")
        lines.append(f"| Freeze in < 7 days   | {summary.get('at_risk_7_days', 0):>5} |")
        lines.append(f"| Freeze in < 14 days  | {summary.get('at_risk_14_days', 0):>5} |")
        lines.append(f"| Freeze in < 30 days  | {summary.get('at_risk_30_days', 0):>5} |")
        lines.append("")

    # Determine the majority module hash
    hash_counts = {}
    for m in mainers:
        h = m.get("module_hash", "")
        if h and h != "None":
            hash_counts[h] = hash_counts.get(h, 0) + 1
    majority_hash = max(hash_counts, key=hash_counts.get) if hash_counts else ""

    def module_hash_status(m):
        h = m.get("module_hash", "")
        if not h or h == "None":
            return "None"
        if h == majority_hash:
            return "Ok"
        return "Not Ok"

    # Determine column widths for the all-mainers table
    cid_width = max((len(m["canister_id"]) for m in mainers), default=11)
    status_width = max(len(STATUS_UNINSTALLED), 6)  # widest status label
    hash_col_width = 11  # "Module Hash" header width

    active_col_width = 6
    burn_col_width = 9
    mem_col_width = 9
    cyc_col_width = 10
    drain_col_width = 10
    freeze_col_width = 10
    days_col_width = 9
    hash_col_width = 11

    def table_header():
        return [
            f"| {'#':<4} | {'Canister ID':<{cid_width}} | {'Status':<{status_width}} | {'Active':<{active_col_width}} | {'Burn Rate':<{burn_col_width}} | {'Mem (MB)':<{mem_col_width}} | {'Cycles (T)':<{cyc_col_width}} | {'Drain/D(B)':<{drain_col_width}} | {'FreezeAt(T)':<{freeze_col_width}} | {'Days Left':<{days_col_width}} | {'Hash':<{hash_col_width}} |",
            f"|{'-' * 6}|{'-' * (cid_width + 2)}|{'-' * (status_width + 2)}|{'-' * (active_col_width + 2)}|{'-' * (burn_col_width + 2)}|{'-' * (mem_col_width + 2)}|{'-' * (cyc_col_width + 2)}|{'-' * (drain_col_width + 2)}|{'-' * (freeze_col_width + 2)}|{'-' * (days_col_width + 2)}|{'-' * (hash_col_width + 2)}|",
        ]

    def active_display(m):
        a = m.get("active")
        if a is True:
            return "Yes"
        elif a is False:
            return "No"
        return ""

    def mem_display(m):
        mem = m.get("memory_bytes")
        if mem is not None:
            return f"{mem / 1_000_000:.1f}"
        return ""

    def cycles_display(m):
        bal = m.get("cycles_balance")
        if bal is not None:
            return f"{bal / 1_000_000_000_000:.2f}"
        return ""

    def drain_display(m):
        d = m.get("daily_drain")
        if d is not None:
            return f"{d / 1_000_000_000:.1f}"
        return ""

    def freeze_at_display(m):
        ft = m.get("freeze_threshold")
        if ft is not None:
            return f"{ft / 1_000_000_000_000:.2f}"
        return ""

    def days_display(m):
        d = m.get("days_until_freeze")
        if d is not None:
            return f"{d:.1f}"
        return ""

    def table_row(idx, m):
        return (
            f"| {idx:<4} "
            f"| {m['canister_id']:<{cid_width}} "
            f"| {m['status']:<{status_width}} "
            f"| {active_display(m):<{active_col_width}} "
            f"| {m.get('burn_rate', ''):<{burn_col_width}} "
            f"| {mem_display(m):>{mem_col_width}} "
            f"| {cycles_display(m):>{cyc_col_width}} "
            f"| {drain_display(m):>{drain_col_width}} "
            f"| {freeze_at_display(m):>{freeze_col_width}} "
            f"| {days_display(m):>{days_col_width}} "
            f"| {module_hash_status(m):<{hash_col_width}} |"
        )

    # Sort: non-healthy first (Frozen, Uninstalled, Stopped, Maintenance, Unavailable, Healthy)
    status_order = {
        STATUS_FROZEN: 0, STATUS_UNINSTALLED: 1, STATUS_STOPPED: 2,
        STATUS_MAINTENANCE: 3, STATUS_UNAVAILABLE: 4, STATUS_HEALTHY: 5,
    }
    sorted_mainers = sorted(mainers, key=lambda m: status_order.get(m["status"], 99))

    lines.append("## All mAIners")
    lines.append("")
    lines.append(f"Ok Module Hash: `{majority_hash}`")
    lines.append("")
    lines.extend(table_header())
    for idx, m in enumerate(sorted_mainers, 1):
        lines.append(table_row(idx, m))
    lines.append("")

    # Filtered tables for problem statuses
    for filter_status in [STATUS_FROZEN, STATUS_UNINSTALLED, STATUS_STOPPED,
                          STATUS_MAINTENANCE, STATUS_UNAVAILABLE]:
        filtered = [m for m in mainers if m["status"] == filter_status]
        if filtered:
            lines.append(f"## {filter_status} mAIners")
            lines.append("")
            lines.extend(table_header())
            for idx, m in enumerate(filtered, 1):
                lines.append(table_row(idx, m))
            lines.append("")

    # Notes section with full error messages for non-healthy canisters
    non_healthy = [m for m in sorted_mainers if m.get("error_message")]
    if non_healthy:
        lines.append("## Notes")
        lines.append("")
        for m in non_healthy:
            lines.append(f"**{m['canister_id']}** ({m['status']}):")
            lines.append(f"> {m['error_message']}")
            lines.append("")

    with open(md_path, 'w') as f:
        f.write('\n'.join(lines) + '\n')


def main(network, workers=10, limit=None):
    log_message("=" * 80)
    log_message(f"Checking status of all ShareAgent mAIners on network '{network}'")
    log_message(f"Using {workers} parallel workers")
    log_message("=" * 80)

    # Step 1: Fetch all mAIners from GameState
    mainers = get_mainers(network)
    if not mainers:
        log_message(f"No mainers found on network '{network}'", "ERROR")
        return

    # Step 2: Filter to ShareAgent only
    share_agents = filter_share_agents(mainers)
    log_message(f"Found {len(share_agents)} ShareAgent mAIners (out of {len(mainers)} total)")

    if not share_agents:
        log_message("No ShareAgent mAIners to check", "ERROR")
        return

    # Step 3: Apply limit if specified
    if limit is not None and limit > 0:
        share_agents = share_agents[:limit]
        log_message(f"Limiting to first {limit} mAIners (for testing)")

    total = len(share_agents)
    log_message(f"Starting status check for {total} mAIners...")
    log_message("")

    # Step 4: Check all canisters in parallel
    all_results = []
    with ThreadPoolExecutor(max_workers=workers) as executor:
        future_to_agent = {
            executor.submit(
                check_canister_status, network, agent["address"],
                agent["owner"], idx + 1, total
            ): agent
            for idx, agent in enumerate(share_agents)
        }

        for future in as_completed(future_to_agent):
            try:
                result = future.result()
                all_results.append(result)
            except Exception as e:
                agent = future_to_agent[future]
                log_message(f"Exception checking {agent['address']}: {e}", "ERROR")
                all_results.append({
                    "canister_id": agent["address"],
                    "owner": agent["owner"],
                    "status": STATUS_UNAVAILABLE,
                    "module_hash": "",
                    "error_message": str(e)[:200],
                    "active": None,
                    "burn_rate": "",
                    "memory_bytes": None,
                    "cycles_balance": None,
                    "daily_drain": None,
                    "freeze_threshold": None,
                    "days_until_freeze": None,
                })

    # Step 5: Aggregate results
    counts = {
        STATUS_HEALTHY: 0,
        STATUS_MAINTENANCE: 0,
        STATUS_STOPPED: 0,
        STATUS_FROZEN: 0,
        STATUS_UNINSTALLED: 0,
        STATUS_UNAVAILABLE: 0,
    }
    active_count = 0
    paused_count = 0
    burn_rate_counts = {"Low": 0, "Medium": 0, "High": 0, "VeryHigh": 0, "Other": 0}

    at_risk_7 = 0
    at_risk_14 = 0
    at_risk_30 = 0

    for r in all_results:
        counts[r["status"]] = counts.get(r["status"], 0) + 1
        if r["status"] == STATUS_HEALTHY:
            if r.get("active") is True:
                active_count += 1
                br = r.get("burn_rate", "")
                if br in burn_rate_counts:
                    burn_rate_counts[br] += 1
                elif br:
                    burn_rate_counts["Other"] += 1
            elif r.get("active") is False:
                paused_count += 1
            # At-risk tracking
            d = r.get("days_until_freeze")
            if d is not None:
                if d < 7:
                    at_risk_7 += 1
                if d < 14:
                    at_risk_14 += 1
                if d < 30:
                    at_risk_30 += 1

    # Step 6: Print summary
    log_message("")
    log_message("=" * 80)
    log_message("STATUS CHECK SUMMARY")
    log_message("=" * 80)
    log_message(f"Total ShareAgent mAIners : {total}")
    for status_name in [STATUS_HEALTHY, STATUS_MAINTENANCE, STATUS_STOPPED,
                        STATUS_FROZEN, STATUS_UNINSTALLED, STATUS_UNAVAILABLE]:
        count = counts[status_name]
        level = "SUCCESS" if status_name == STATUS_HEALTHY and count > 0 else \
                "ERROR" if count > 0 and status_name != STATUS_HEALTHY else "INFO"
        log_message(f"  {status_name:<13}: {count}", level)
    log_message("")
    if counts[STATUS_HEALTHY] > 0:
        log_message(f"Healthy breakdown:")
        log_message(f"  Active        : {active_count}", "SUCCESS" if active_count > 0 else "INFO")
        log_message(f"  Paused        : {paused_count}", "ERROR" if paused_count > 0 else "INFO")
        log_message(f"  Active burn rates:")
        for br_name in ["Low", "Medium", "High", "VeryHigh", "Other"]:
            if burn_rate_counts[br_name] > 0:
                log_message(f"    {br_name:<10}: {burn_rate_counts[br_name]}")
        log_message("")
        log_message(f"Freeze risk (healthy mAIners):")
        log_message(f"  Freeze in < 7 days : {at_risk_7}", "ERROR" if at_risk_7 > 0 else "INFO")
        log_message(f"  Freeze in < 14 days: {at_risk_14}", "ERROR" if at_risk_14 > 0 else "INFO")
        log_message(f"  Freeze in < 30 days: {at_risk_30}", "ERROR" if at_risk_30 > 0 else "INFO")
        log_message("")

    # Print non-healthy canisters
    non_healthy = [r for r in all_results if r["status"] != STATUS_HEALTHY]
    if non_healthy:
        log_message("NON-HEALTHY MAINERS:", "ERROR")
        for r in non_healthy:
            error_info = f" — {r['error_message'][:80]}" if r.get("error_message") else ""
            log_message(f"  {r['canister_id']} [{r['status']}]{error_info}", "ERROR")
        log_message("")

    if not non_healthy:
        log_message("All mAIners are healthy!", "SUCCESS")
        log_message("")

    # Step 7: Write output files
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    date_prefix = datetime.now().strftime("%Y-%m-%d")
    logs_dir = os.path.join(SCRIPT_DIR, "logs-mainer-analysis")
    os.makedirs(logs_dir, exist_ok=True)

    output_data = {
        "timestamp": timestamp,
        "network": network,
        "summary": {
            "total_share_agents": total,
            "healthy": counts[STATUS_HEALTHY],
            "active": active_count,
            "paused": paused_count,
            "burn_rate_low": burn_rate_counts["Low"],
            "burn_rate_medium": burn_rate_counts["Medium"],
            "burn_rate_high": burn_rate_counts["High"],
            "burn_rate_very_high": burn_rate_counts["VeryHigh"],
            "burn_rate_other": burn_rate_counts["Other"],
            "maintenance": counts[STATUS_MAINTENANCE],
            "stopped": counts[STATUS_STOPPED],
            "frozen": counts[STATUS_FROZEN],
            "uninstalled": counts[STATUS_UNINSTALLED],
            "unavailable": counts[STATUS_UNAVAILABLE],
            "at_risk_7_days": at_risk_7,
            "at_risk_14_days": at_risk_14,
            "at_risk_30_days": at_risk_30,
        },
        "mainers": sorted(all_results, key=lambda r: r["canister_id"]),
    }

    json_path = os.path.join(logs_dir, f"{date_prefix}-check_mAIner_status-{network}.json")
    with open(json_path, 'w') as f:
        json.dump(output_data, f, indent=2)
    log_message(f"JSON report saved to: {os.path.abspath(json_path)}")

    md_path = os.path.join(logs_dir, f"{date_prefix}-check_mAIner_status-{network}.md")
    write_markdown_report(output_data, md_path)
    log_message(f"Markdown report saved to: {os.path.abspath(md_path)}")
    log_message("")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Check status of all ShareAgent mAIners (Healthy/Maintenance/Stopped/Frozen/Uninstalled/Unavailable)."
    )
    parser.add_argument(
        "--network",
        choices=["local", "ic", "testing", "demo", "development", "prd"],
        default="local",
        help="Specify the network to use (default: local)",
    )
    parser.add_argument(
        "--workers",
        type=int,
        default=10,
        help="Number of parallel workers (default: 10)",
    )
    parser.add_argument(
        "--limit",
        type=int,
        default=None,
        help="Limit number of mainers to check (for testing)",
    )
    args = parser.parse_args()
    main(args.network, args.workers, args.limit)
