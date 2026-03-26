#!/bin/bash
# run_single_scenario.sh - Run a single SIPP scenario

SCENARIO="$1"
TARGET="$2"
RATE="${3:-10}"
DURATION="${4:-60}"

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_DIR="logs/functional/${SCENARIO}_${TIMESTAMP}"
mkdir -p "$LOG_DIR"

echo "Running scenario: $SCENARIO"
echo "Target: $TARGET"
echo "Rate: $RATE CPS"
echo "Duration: $DURATION seconds"

# Find the scenario file (could be in subdirectories)
SCENARIO_FILE=$(find scenarios -name "${SCENARIO}.xml" -type f | head -1)

if [ -z "$SCENARIO_FILE" ]; then
    echo "Error: Scenario ${SCENARIO}.xml not found"
    exit 1
fi

echo "Using scenario: $SCENARIO_FILE"

sipp "$TARGET" \
    -sf "$SCENARIO_FILE" \
    -r "$RATE" \
    -d "$((DURATION * 1000))" \
    -trace_msg -message_file "$LOG_DIR/messages.log" \
    -trace_screen -screen_file "$LOG_DIR/screen.log" \
    -trace_err -error_file "$LOG_DIR/error.log" \
    -trace_stat -stf "$LOG_DIR/stats.csv"
