#!/usr/bin/env python3
import time
import re
import subprocess
from prometheus_client import start_http_server, Gauge, Counter

# Metrics matching dashboard 6935 - FIXED (no duplicates)
opensips_up = Gauge('opensips_up', 'OpenSIPS is up')
opensips_core_uptime_seconds = Gauge('opensips_core_uptime_seconds', 'OpenSIPS uptime in seconds')

# Core statistics - FIXED: removed duplicate definitions
opensips_core_requests_total = Counter('opensips_core_requests_total', 'Total core requests')
opensips_core_replies_total = Counter('opensips_core_replies_total', 'Total core replies')
opensips_core_bad_URIs_rcvd = Gauge('opensips_core_bad_URIs_rcvd', 'Bad URIs received')
opensips_core_bad_msg_hdr = Gauge('opensips_core_bad_msg_hdr', 'Bad message headers')
opensips_core_unsupported_methods = Gauge('opensips_core_unsupported_methods', 'Unsupported methods')

# Memory statistics
opensips_shmem_total_size = Gauge('opensips_shmem_total_size', 'Shared memory total size')
opensips_shmem_free_size = Gauge('opensips_shmem_free_size', 'Shared memory free size')
opensips_shmem_real_used_size = Gauge('opensips_shmem_real_used_size', 'Shared memory used size')
opensips_shmem_fragments = Gauge('opensips_shmem_fragments', 'Shared memory fragments')

opensips_pkmem_total_size = Gauge('opensips_pkmem_total_size', 'Private memory total size')
opensips_pkmem_free_size = Gauge('opensips_pkmem_free_size', 'Private memory free size')
opensips_pkmem_real_used_size = Gauge('opensips_pkmem_real_used_size', 'Private memory used size')
opensips_pkmem_fragments = Gauge('opensips_pkmem_fragments', 'Private memory fragments')

# Dialog statistics
opensips_dialog_dialogs = Gauge('opensips_dialog_dialogs', 'Active dialogs')

# Load statistics
opensips_load_1m = Gauge('opensips_load_1m', 'Load 1 minute')
opensips_load_10m = Gauge('opensips_load_10m', 'Load 10 minutes')
opensips_load_all_1m = Gauge('opensips_load_all_1m', 'Load all 1 minute')
opensips_load_all_10m = Gauge('opensips_load_all_10m', 'Load all 10 minutes')

# TM (Transaction) module  
opensips_tm_transactions_total = Counter('opensips_tm_transactions_total', 'Total transactions')
opensips_tm_inuse_transactions = Gauge('opensips_tm_inuse_transactions', 'In-use transactions')

# User location
opensips_usrloc_users = Gauge('opensips_usrloc_users', 'User location users')
opensips_usrloc_contacts = Gauge('opensips_usrloc_contacts', 'User location contacts')
opensips_userloc_registered_users_total = Gauge('opensips_userloc_registered_users_total', 'Total registered users')

# Net waiting
opensips_net_waiting = Gauge('opensips_net_waiting', 'Net waiting TCP connections')

def query_opensips(command):
    try:
        result = subprocess.run(
            ['docker', 'exec', 'opensips', 'opensips-cli', '-x', 'mi', command],
            capture_output=True, text=True, timeout=5
        )
        return result.stdout if result.returncode == 0 else None
    except Exception as e:
        print(f"Error querying OpenSIPS: {e}")
        return None

def collect_metrics():
    # Check if OpenSIPS is up
    uptime_output = query_opensips('uptime')
    if not uptime_output:
        opensips_up.set(0)
        return
    
    opensips_up.set(1)
    
    # Parse uptime (in seconds) - format: "Now: timestamp\nUp since: timestamp\nUp time: seconds"
    uptime_match = re.search(r'Up time:\s+(\d+)', uptime_output)
    if uptime_match:
        opensips_core_uptime_seconds.set(float(uptime_match.group(1)))
    else:
        # Alternative: calculate from "Now" and "Up since"
        now_match = re.search(r'Now::\s+(\d+)', uptime_output)
        since_match = re.search(r'Up since::\s+(\d+)', uptime_output)
        if now_match and since_match:
            opensips_core_uptime_seconds.set(float(now_match.group(1)) - float(since_match.group(1)))

    # Get statistics using get_statistics
    # Core statistics
    stats = query_opensips('get_statistics core:')
    if stats:
        # Parse bad URIs
        match = re.search(r'bad_URIs_rcvd::\s*(\d+)', stats)
        if match:
            opensips_core_bad_URIs_rcvd.set(float(match.group(1)))
        
        # Parse bad headers
        match = re.search(r'bad_msg_hdr::\s*(\d+)', stats)
        if match:
            opensips_core_bad_msg_hdr.set(float(match.group(1)))
        
        # Parse unsupported methods
        match = re.search(r'unsupported_methods::\s*(\d+)', stats)
        if match:
            opensips_core_unsupported_methods.set(float(match.group(1)))

    # Shared memory
    stats = query_opensips('get_statistics shmem:')
    if stats:
        match = re.search(r'total_size::\s*(\d+)', stats)
        if match:
            opensips_shmem_total_size.set(float(match.group(1)))
        
        match = re.search(r'free_size::\s*(\d+)', stats)
        if match:
            opensips_shmem_free_size.set(float(match.group(1)))
        
        match = re.search(r'real_used_size::\s*(\d+)', stats)
        if match:
            opensips_shmem_real_used_size.set(float(match.group(1)))
        
        match = re.search(r'fragments::\s*(\d+)', stats)
        if match:
            opensips_shmem_fragments.set(float(match.group(1)))

    # Private memory
    stats = query_opensips('get_statistics pkmem:')
    if stats:
        match = re.search(r'total_size::\s*(\d+)', stats)
        if match:
            opensips_pkmem_total_size.set(float(match.group(1)))
        
        match = re.search(r'free_size::\s*(\d+)', stats)
        if match:
            opensips_pkmem_free_size.set(float(match.group(1)))
        
        match = re.search(r'real_used_size::\s*(\d+)', stats)
        if match:
            opensips_pkmem_real_used_size.set(float(match.group(1)))
        
        match = re.search(r'fragments::\s*(\d+)', stats)
        if match:
            opensips_pkmem_fragments.set(float(match.group(1)))

    # Dialog statistics
    dlg_list = query_opensips('dlg_list')
    if dlg_list:
        dialog_count = dlg_list.count('"callid":')
        opensips_dialog_dialogs.set(dialog_count)

    # Load statistics
    stats = query_opensips('get_statistics load:')
    if stats:
        match = re.search(r'load_1m::\s*(\d+)', stats)
        if match:
            opensips_load_1m.set(float(match.group(1)))
        
        match = re.search(r'load_10m::\s*(\d+)', stats)
        if match:
            opensips_load_10m.set(float(match.group(1)))
        
        match = re.search(r'load_all_1m::\s*(\d+)', stats)
        if match:
            opensips_load_all_1m.set(float(match.group(1)))
        
        match = re.search(r'load_all_10m::\s*(\d+)', stats)
        if match:
            opensips_load_all_10m.set(float(match.group(1)))

    # TM statistics
    stats = query_opensips('get_statistics tm:')
    if stats:
        match = re.search(r'inuse_transactions::\s*(\d+)', stats)
        if match:
            opensips_tm_inuse_transactions.set(float(match.group(1)))

    # User location
    ul_dump = query_opensips('ul_dump')
    if ul_dump:
        users = ul_dump.count('"aor":')
        contacts = ul_dump.count('"contact":')
        opensips_usrloc_users.set(users)
        opensips_usrloc_contacts.set(contacts)
        opensips_userloc_registered_users_total.set(users)

    # Net statistics  
    stats = query_opensips('get_statistics net:')
    if stats:
        match = re.search(r'waiting_tcp::\s*(\d+)', stats)
        if match:
            opensips_net_waiting.set(float(match.group(1)))

if __name__ == '__main__':
    start_http_server(8000)
    print("Enhanced OpenSIPS Exporter started on port 8000")
    print("Querying OpenSIPS statistics module")

    while True:
        try:
            collect_metrics()
        except Exception as e:
            print(f"Error collecting metrics: {e}")
        time.sleep(15)
