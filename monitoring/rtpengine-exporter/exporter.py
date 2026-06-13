#!/usr/bin/env python3
import time
import subprocess
from prometheus_client import start_http_server, Gauge

rtpengine_up = Gauge('rtpengine_up', 'RTPEngine is up')
rtpengine_sessions = Gauge('rtpengine_sessions', 'Active sessions')
rtpengine_calls_total = Gauge('rtpengine_calls_total', 'Total calls processed')

def get_logs():
    try:
        result = subprocess.run(
            ['docker', 'logs', '--tail', '100', 'rtpengine'],
            capture_output=True, text=True, timeout=5
        )
        return result.stdout + result.stderr
    except:
        return ""

def collect_metrics():
    logs = get_logs()
    rtpengine_up.set(1 if logs else 0)
    
    if logs:
        creating = logs.count('Creating new call')
        closing = logs.count('Final packet stats')
        rtpengine_sessions.set(max(0, creating - closing))
        rtpengine_calls_total.set(creating)

if __name__ == '__main__':
    start_http_server(9092)
    print("RTPEngine Exporter started on port 9092")
    while True:
        try:
            collect_metrics()
        except Exception as e:
            print(f"Error: {e}")
        time.sleep(15)
