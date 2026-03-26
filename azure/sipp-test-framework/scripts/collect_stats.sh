#!/bin/bash
# collect_stats.sh - Collect and organize test statistics

set -euo pipefail

TEST_TYPE="${1:-unknown}"
TIMESTAMP="${2:-$(date +%Y%m%d_%H%M%S)}"

LOGS_DIR="logs"
RESULTS_DIR="results/${TEST_TYPE}"
RESULT_PATH="${RESULTS_DIR}/${TIMESTAMP}"

# Create result directories
mkdir -p "${RESULT_PATH}"/{logs,stats,reports}

echo "=========================================="
echo "Collecting Statistics"
echo "Test Type: ${TEST_TYPE}"
echo "Timestamp: ${TIMESTAMP}"
echo "=========================================="

# Find all log directories for this test run
LOG_DIRS=$(find "${LOGS_DIR}" -type d -name "*${TIMESTAMP}*" 2>/dev/null || true)

if [ -z "$LOG_DIRS" ]; then
    echo "Warning: No log directories found for timestamp ${TIMESTAMP}"
    exit 0
fi

# Process each log directory
for LOG_DIR in $LOG_DIRS; do
    TEST_NAME=$(basename "$LOG_DIR")
    echo "Processing: ${TEST_NAME}"
    
    # Copy all logs to results
    cp -r "$LOG_DIR" "${RESULT_PATH}/logs/"
    
    # Parse statistics if CSV exists
    if [ -f "${LOG_DIR}/stats.csv" ]; then
        echo "  - Parsing statistics..."
        python3 << 'EOF' - "${LOG_DIR}/stats.csv" "${RESULT_PATH}/stats/${TEST_NAME}_summary.json"
import sys
import csv
import json
from collections import defaultdict

csv_file = sys.argv[1]
output_file = sys.argv[2]

stats = {
    'test_name': '',
    'total_calls': 0,
    'successful_calls': 0,
    'failed_calls': 0,
    'avg_response_time': 0.0,
    'max_response_time': 0.0,
    'min_response_time': float('inf'),
    'avg_call_duration': 0.0,
    'cps_achieved': 0.0,
    'errors': defaultdict(int)
}

try:
    with open(csv_file, 'r') as f:
        reader = csv.DictReader(f, delimiter=';')
        rows = list(reader)
        
        if rows:
            last_row = rows[-1]
            stats['total_calls'] = int(last_row.get('TotalCallCreated', 0))
            stats['successful_calls'] = int(last_row.get('SuccessfulCall', 0))
            stats['failed_calls'] = int(last_row.get('FailedCall', 0))
            stats['cps_achieved'] = float(last_row.get('CurrentCallRate', 0))
            
            # Calculate average response times
            response_times = []
            for row in rows:
                if 'ResponseTime' in row and row['ResponseTime']:
                    try:
                        rt = float(row['ResponseTime'])
                        response_times.append(rt)
                    except ValueError:
                        pass
            
            if response_times:
                stats['avg_response_time'] = sum(response_times) / len(response_times)
                stats['max_response_time'] = max(response_times)
                stats['min_response_time'] = min(response_times)
    
    with open(output_file, 'w') as f:
        json.dump(stats, f, indent=2)
    
    print(f"Statistics summary written to {output_file}")
    
except Exception as e:
    print(f"Error processing stats: {e}", file=sys.stderr)
    sys.exit(1)
EOF
    fi
    
    # Parse error logs
    if [ -f "${LOG_DIR}/error.log" ]; then
        echo "  - Analyzing errors..."
        ERROR_COUNT=$(grep -c "ERROR" "${LOG_DIR}/error.log" 2>/dev/null || echo "0")
        echo "    Errors found: ${ERROR_COUNT}"
        
        # Extract unique error types
        grep "ERROR" "${LOG_DIR}/error.log" 2>/dev/null | \
            awk '{print $NF}' | sort | uniq -c | \
            sort -rn > "${RESULT_PATH}/stats/${TEST_NAME}_errors.txt" || true
    fi
    
    # Summarize message flow
    if [ -f "${LOG_DIR}/messages.log" ]; then
        echo "  - Analyzing message flow..."
        grep -E "^(Sent|Recv)" "${LOG_DIR}/messages.log" 2>/dev/null | \
            awk '{print $1, $2}' | sort | uniq -c | \
            sort -rn > "${RESULT_PATH}/stats/${TEST_NAME}_messages.txt" || true
    fi
done

# Generate consolidated summary
cat > "${RESULT_PATH}/summary.txt" << EOF
========================================
Test Summary Report
========================================
Test Type:    ${TEST_TYPE}
Timestamp:    ${TIMESTAMP}
Date:         $(date)
========================================

Test Runs:
EOF

# Add individual test summaries
for SUMMARY in "${RESULT_PATH}"/stats/*_summary.json; do
    if [ -f "$SUMMARY" ]; then
        TEST_NAME=$(basename "$SUMMARY" _summary.json)
        echo "" >> "${RESULT_PATH}/summary.txt"
        echo "--- ${TEST_NAME} ---" >> "${RESULT_PATH}/summary.txt"
        
        # Extract key metrics using jq if available, otherwise use python
        if command -v jq &> /dev/null; then
            jq -r 'to_entries | .[] | "\(.key): \(.value)"' "$SUMMARY" >> "${RESULT_PATH}/summary.txt"
        else
            python3 -c "import json; data=json.load(open('$SUMMARY')); print('\n'.join(f'{k}: {v}' for k,v in data.items()))" >> "${RESULT_PATH}/summary.txt"
        fi
    fi
done

echo ""
echo "=========================================="
echo "Statistics Collection Complete"
echo "Results saved to: ${RESULT_PATH}"
echo "=========================================="

# Print summary
cat "${RESULT_PATH}/summary.txt"
