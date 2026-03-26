#!/usr/bin/env python3
import time
import re
import subprocess
from prometheus_client import start_http_server, Gauge, Counter

# All metrics from dashboard 17071
freeswitch_up = Gauge('freeswitch_up', 'FreeSWITCH is up')
freeswitch_uptime_seconds = Gauge('freeswitch_uptime_seconds', 'FreeSWITCH uptime in seconds')
freeswitch_current_sessions = Gauge('freeswitch_current_sessions', 'Current sessions')
freeswitch_current_sessions_peak = Gauge('freeswitch_current_sessions_peak', 'Peak sessions')
freeswitch_current_sessions_peak_last_5min = Gauge('freeswitch_current_sessions_peak_last_5min', 'Peak sessions last 5min')
freeswitch_sessions_total = Counter('freeswitch_sessions_total', 'Total sessions since startup')
freeswitch_max_sessions = Gauge('freeswitch_max_sessions', 'Maximum sessions')
freeswitch_current_calls = Gauge('freeswitch_current_calls', 'Current calls')
freeswitch_bridged_calls = Gauge('freeswitch_bridged_calls', 'Bridged calls')
freeswitch_detailed_calls = Gauge('freeswitch_detailed_calls', 'Detailed calls')
freeswitch_current_sps = Gauge('freeswitch_current_sps', 'Sessions per second')
freeswitch_current_sps_peak_last_5min = Gauge('freeswitch_current_sps_peak_last_5min', 'Peak SPS last 5min')
freeswitch_max_sps = Gauge('freeswitch_max_sps', 'Maximum SPS')
freeswitch_current_idle_cpu = Gauge('freeswitch_current_idle_cpu', 'Idle CPU percentage')
freeswitch_registrations = Gauge('freeswitch_registrations', 'Registrations', ['profile'])

def query_freeswitch(command):
    try:
        result = subprocess.run(
            ['docker', 'exec', 'freeswitch', 'fs_cli', '-x', command],
            capture_output=True, text=True, timeout=5
        )
        return result.stdout if result.returncode == 0 else None
    except Exception as e:
        print(f"Error querying FreeSWITCH: {e}")
        return None

def parse_time_to_seconds(time_str):
    """Convert time string like '0 years, 0 days, 0 hours, 5 minutes, 23 seconds' to seconds"""
    seconds = 0
    patterns = {
        'years': 31536000,
        'days': 86400,
        'hours': 3600,
        'minutes': 60,
        'seconds': 1
    }
    for unit, multiplier in patterns.items():
        match = re.search(rf'(\d+)\s+{unit}', time_str)
        if match:
            seconds += int(match.group(1)) * multiplier
    return seconds

def collect_metrics():
    # Check if FreeSWITCH is up
    status = query_freeswitch('status')
    freeswitch_up.set(1 if status else 0)

    if not status:
        return

    # Parse status output for ALL metrics
    if status:
        # Uptime - look for pattern like "0 years, 0 days, 0 hours, 5 minutes, 23 seconds"
        uptime_match = re.search(r'(\d+)\s+years?,\s+(\d+)\s+days?,\s+(\d+)\s+hours?,\s+(\d+)\s+minutes?,\s+(\d+)\s+seconds?', status)
        if uptime_match:
            years, days, hours, minutes, seconds = map(int, uptime_match.groups())
            total_seconds = seconds + (minutes * 60) + (hours * 3600) + (days * 86400) + (years * 31536000)
            freeswitch_uptime_seconds.set(total_seconds)
        
        # Session counts - pattern: "10 session(s) since startup"
        session_total_match = re.search(r'(\d+)\s+session\(s\)\s+since startup', status)
        if session_total_match:
            freeswitch_sessions_total._value.set(int(session_total_match.group(1)))
        
        # Current sessions - pattern: "5 session(s) - peak 10, last 5min 8"
        current_match = re.search(r'(\d+)\s+session\(s\)\s+-\s+peak\s+(\d+),\s+last 5min\s+(\d+)', status)
        if current_match:
            freeswitch_current_sessions.set(int(current_match.group(1)))
            freeswitch_current_sessions_peak.set(int(current_match.group(2)))
            freeswitch_current_sessions_peak_last_5min.set(int(current_match.group(3)))
        
        # Max sessions - pattern: "1000 session(s) max"
        max_match = re.search(r'(\d+)\s+session\(s\)\s+max', status)
        if max_match:
            freeswitch_max_sessions.set(int(max_match.group(1)))
        
        # SPS - pattern: "5 session(s) per Sec out of max 30, peak 10, last 5min 8"
        sps_match = re.search(r'(\d+)\s+session\(s\)\s+per\s+Sec\s+out\s+of\s+max\s+(\d+),\s+peak\s+(\d+),\s+last 5min\s+(\d+)', status)
        if sps_match:
            freeswitch_current_sps.set(int(sps_match.group(1)))
            freeswitch_max_sps.set(int(sps_match.group(2)))
            # Note: peak is overall, last 5min is what we want
            freeswitch_current_sps_peak_last_5min.set(int(sps_match.group(4)))
        
        # Idle CPU - pattern: "98.50% idle cpu"
        cpu_match = re.search(r'([\d.]+)%\s+idle\s+cpu', status)
        if cpu_match:
            freeswitch_current_idle_cpu.set(float(cpu_match.group(1)))

    # Current calls
    calls = query_freeswitch('show calls count')
    if calls:
        match = re.search(r'(\d+)\s+total', calls)
        if match:
            freeswitch_current_calls.set(int(match.group(1)))

    # Channels (detailed calls)
    channels = query_freeswitch('show channels count')
    if channels:
        match = re.search(r'(\d+)\s+total', channels)
        if match:
            freeswitch_detailed_calls.set(int(match.group(1)))

    # Bridged calls - query actual calls and count bridged ones
    calls_detail = query_freeswitch('show calls')
    if calls_detail:
        # Count lines with bridged state
        bridged = calls_detail.count('ACTIVE')
        freeswitch_bridged_calls.set(bridged)

    # Registrations
    regs = query_freeswitch('show registrations count')
    if regs:
        match = re.search(r'(\d+)\s+total', regs)
        if match:
            total_regs = int(match.group(1))
            freeswitch_registrations.labels(profile='total').set(total_regs)

if __name__ == '__main__':
    start_http_server(8000)
    print("Enhanced FreeSWITCH Exporter started on port 8000")
    print("Collecting comprehensive FreeSWITCH statistics")

    while True:
        try:
            collect_metrics()
        except Exception as e:
            print(f"Error collecting metrics: {e}")
        time.sleep(15)
