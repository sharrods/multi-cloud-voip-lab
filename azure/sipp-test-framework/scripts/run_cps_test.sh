#!/bin/bash
# run_cps_test.sh - CPS (Calls Per Second) ramp test

set -euo pipefail

TARGET="${1:-127.0.0.1:5060}"
MAX_CPS="${2:-100}"
STEP="${3:-10}"
DURATION="${4:-300}"

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
TEST_ID="cps_test_${TIMESTAMP}"
LOG_DIR="logs/cps/${TEST_ID}"

mkdir -p "${LOG_DIR}"

echo "=========================================="
echo "CPS Ramp Test"
echo "=========================================="
echo "Target:       ${TARGET}"
echo "Max CPS:      ${MAX_CPS}"
echo "Step:         ${STEP}"
echo "Duration:     ${DURATION}s per step"
echo "Test ID:      ${TEST_ID}"
echo "=========================================="

# Create results file
RESULTS_FILE="${LOG_DIR}/cps_results.csv"
echo "CPS,Timestamp,TotalCalls,SuccessfulCalls,FailedCalls,CurrentCalls,AvgResponseTime" > "${RESULTS_FILE}"

# Ramp up CPS
CURRENT_CPS=${STEP}

while [ ${CURRENT_CPS} -le ${MAX_CPS} ]; do
    echo ""
    echo "=========================================="
    echo "Testing at ${CURRENT_CPS} CPS..."
    echo "=========================================="
    
    STEP_LOG_DIR="${LOG_DIR}/cps_${CURRENT_CPS}"
    mkdir -p "${STEP_LOG_DIR}"
    
    # Calculate number of calls for this step
    NUM_CALLS=$((CURRENT_CPS * DURATION))
    
    # Run SIPP test at current CPS rate
    sipp ${TARGET} \
        -sf scenarios/basic/basic_uac.xml \
        -r ${CURRENT_CPS} \
        -l ${CURRENT_CPS} \
        -m ${NUM_CALLS} \
        -d ${DURATION}000 \
        -trace_msg -message_file "${STEP_LOG_DIR}/messages.log" \
        -trace_screen -screen_file "${STEP_LOG_DIR}/screen.log" \
        -trace_err -error_file "${STEP_LOG_DIR}/error.log" \
        -trace_stat -stf "${STEP_LOG_DIR}/stats.csv" \
        -fd 1 \
        -timeout 30s \
        -timeout_error \
        -default_behaviors none \
        || {
            echo "ERROR: Test failed at ${CURRENT_CPS} CPS"
            echo "Maximum sustainable CPS: $((CURRENT_CPS - STEP))"
            break
        }
    
    # Parse results from stats file
    if [ -f "${STEP_LOG_DIR}/stats.csv" ]; then
        LAST_LINE=$(tail -1 "${STEP_LOG_DIR}/stats.csv")
        
        # Extract metrics (adjust column numbers based on your SIPP version)
        TOTAL_CALLS=$(echo "$LAST_LINE" | cut -d';' -f2)
        SUCCESSFUL=$(echo "$LAST_LINE" | cut -d';' -f3)
        FAILED=$(echo "$LAST_LINE" | cut -d';' -f4)
        CURRENT=$(echo "$LAST_LINE" | cut -d';' -f5)
        
        # Calculate success rate
        if [ ${TOTAL_CALLS:-0} -gt 0 ]; then
            SUCCESS_RATE=$(awk "BEGIN {printf \"%.2f\", (${SUCCESSFUL:-0} / ${TOTAL_CALLS}) * 100}")
        else
            SUCCESS_RATE="0.00"
        fi
        
        echo "  Total Calls:       ${TOTAL_CALLS}"
        echo "  Successful:        ${SUCCESSFUL}"
        echo "  Failed:            ${FAILED}"
        echo "  Success Rate:      ${SUCCESS_RATE}%"
        
        # Append to results file
        echo "${CURRENT_CPS},$(date +%Y-%m-%d_%H:%M:%S),${TOTAL_CALLS},${SUCCESSFUL},${FAILED},${CURRENT},-" >> "${RESULTS_FILE}"
        
        # Check if we're hitting failure threshold
        FAIL_RATE=$(awk "BEGIN {printf \"%.2f\", (${FAILED:-0} / ${TOTAL_CALLS:-1}) * 100}")
        FAIL_THRESHOLD=5.0
        
        if (( $(echo "${FAIL_RATE} > ${FAIL_THRESHOLD}" | bc -l) )); then
            echo ""
            echo "=========================================="
            echo "WARNING: Failure rate (${FAIL_RATE}%) exceeds threshold (${FAIL_THRESHOLD}%)"
            echo "Maximum sustainable CPS: $((CURRENT_CPS - STEP))"
            echo "=========================================="
            break
        fi
    fi
    
    # Increment CPS
    CURRENT_CPS=$((CURRENT_CPS + STEP))
    
    # Cool down period between ramps
    if [ ${CURRENT_CPS} -le ${MAX_CPS} ]; then
        echo ""
        echo "Cool down for 10 seconds..."
        sleep 10
    fi
done

echo ""
echo "=========================================="
echo "CPS Test Complete"
echo "=========================================="
echo "Results: ${LOG_DIR}"
echo "Summary: ${RESULTS_FILE}"
echo "=========================================="

# Generate graph if gnuplot is available
if command -v gnuplot &> /dev/null; then
    echo "Generating CPS performance graph..."
    gnuplot << EOF
set terminal png size 1200,800
set output '${LOG_DIR}/cps_graph.png'
set title 'CPS Performance Test Results'
set xlabel 'CPS (Calls Per Second)'
set ylabel 'Call Count'
set grid
set datafile separator ','
set key autotitle columnhead
plot '${RESULTS_FILE}' using 1:3 with linespoints title 'Total Calls', \
     '${RESULTS_FILE}' using 1:4 with linespoints title 'Successful', \
     '${RESULTS_FILE}' using 1:5 with linespoints title 'Failed'
EOF
    echo "Graph saved: ${LOG_DIR}/cps_graph.png"
fi

echo ""
echo "CPS test logs saved to: ${LOG_DIR}"
