#!/bin/bash
# generate_report.sh - Generate HTML test report

set -euo pipefail

TEST_TYPE="${1:-unknown}"
TIMESTAMP="${2:-$(date +%Y%m%d_%H%M%S)}"

RESULTS_DIR="results/${TEST_TYPE}/${TIMESTAMP}"
REPORTS_DIR="reports"
REPORT_FILE="${REPORTS_DIR}/${TEST_TYPE}_${TIMESTAMP}.html"

mkdir -p "${REPORTS_DIR}"

if [ ! -d "${RESULTS_DIR}" ]; then
    echo "Error: Results directory not found: ${RESULTS_DIR}"
    exit 1
fi

echo "Generating HTML report: ${REPORT_FILE}"

# Start HTML document
cat > "${REPORT_FILE}" << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>SIPP Test Report</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            padding: 20px;
            color: #333;
        }
        
        .container {
            max-width: 1400px;
            margin: 0 auto;
            background: white;
            border-radius: 12px;
            box-shadow: 0 20px 60px rgba(0,0,0,0.3);
            overflow: hidden;
        }
        
        .header {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 40px;
            text-align: center;
        }
        
        .header h1 {
            font-size: 2.5em;
            margin-bottom: 10px;
            text-shadow: 2px 2px 4px rgba(0,0,0,0.2);
        }
        
        .header .meta {
            font-size: 1.1em;
            opacity: 0.9;
        }
        
        .content {
            padding: 40px;
        }
        
        .summary-cards {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 20px;
            margin-bottom: 40px;
        }
        
        .card {
            background: linear-gradient(135deg, #f5f7fa 0%, #c3cfe2 100%);
            padding: 25px;
            border-radius: 10px;
            box-shadow: 0 4px 6px rgba(0,0,0,0.1);
            transition: transform 0.2s;
        }
        
        .card:hover {
            transform: translateY(-5px);
            box-shadow: 0 8px 12px rgba(0,0,0,0.15);
        }
        
        .card.success {
            background: linear-gradient(135deg, #84fab0 0%, #8fd3f4 100%);
        }
        
        .card.error {
            background: linear-gradient(135deg, #fa709a 0%, #fee140 100%);
        }
        
        .card.info {
            background: linear-gradient(135deg, #a8edea 0%, #fed6e3 100%);
        }
        
        .card h3 {
            font-size: 0.9em;
            text-transform: uppercase;
            letter-spacing: 1px;
            margin-bottom: 10px;
            color: #555;
        }
        
        .card .value {
            font-size: 2.5em;
            font-weight: bold;
            color: #333;
        }
        
        .section {
            margin-bottom: 40px;
        }
        
        .section h2 {
            font-size: 1.8em;
            margin-bottom: 20px;
            color: #667eea;
            border-bottom: 3px solid #667eea;
            padding-bottom: 10px;
        }
        
        .test-result {
            background: #f8f9fa;
            padding: 20px;
            border-radius: 8px;
            margin-bottom: 20px;
            border-left: 5px solid #667eea;
        }
        
        .test-result h3 {
            color: #333;
            margin-bottom: 15px;
            font-size: 1.3em;
        }
        
        .metrics {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 15px;
        }
        
        .metric {
            background: white;
            padding: 15px;
            border-radius: 6px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.05);
        }
        
        .metric-label {
            font-size: 0.85em;
            color: #666;
            text-transform: uppercase;
            letter-spacing: 0.5px;
            margin-bottom: 5px;
        }
        
        .metric-value {
            font-size: 1.5em;
            font-weight: bold;
            color: #333;
        }
        
        .status-badge {
            display: inline-block;
            padding: 5px 15px;
            border-radius: 20px;
            font-size: 0.85em;
            font-weight: bold;
            text-transform: uppercase;
        }
        
        .status-pass {
            background: #10b981;
            color: white;
        }
        
        .status-fail {
            background: #ef4444;
            color: white;
        }
        
        .status-warn {
            background: #f59e0b;
            color: white;
        }
        
        table {
            width: 100%;
            border-collapse: collapse;
            background: white;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
            border-radius: 8px;
            overflow: hidden;
        }
        
        th {
            background: #667eea;
            color: white;
            padding: 15px;
            text-align: left;
            font-weight: 600;
        }
        
        td {
            padding: 12px 15px;
            border-bottom: 1px solid #e5e7eb;
        }
        
        tr:hover {
            background: #f9fafb;
        }
        
        .footer {
            background: #f8f9fa;
            padding: 20px 40px;
            text-align: center;
            color: #666;
            font-size: 0.9em;
        }
        
        .progress-bar {
            width: 100%;
            height: 30px;
            background: #e5e7eb;
            border-radius: 15px;
            overflow: hidden;
            margin-top: 10px;
        }
        
        .progress-fill {
            height: 100%;
            background: linear-gradient(90deg, #667eea 0%, #764ba2 100%);
            display: flex;
            align-items: center;
            justify-content: center;
            color: white;
            font-weight: bold;
            transition: width 0.3s ease;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>📊 SIPP Test Report</h1>
            <div class="meta">
EOF

# Add dynamic header content
cat >> "${REPORT_FILE}" << EOF
                <div>Test Type: <strong>${TEST_TYPE}</strong></div>
                <div>Timestamp: <strong>${TIMESTAMP}</strong></div>
                <div>Generated: <strong>$(date)</strong></div>
EOF

cat >> "${REPORT_FILE}" << 'EOF'
            </div>
        </div>
        
        <div class="content">
EOF

# Add summary cards
TOTAL_TESTS=$(find "${RESULTS_DIR}/logs" -maxdepth 1 -type d | wc -l)
TOTAL_TESTS=$((TOTAL_TESTS - 1)) # Subtract parent directory

cat >> "${REPORT_FILE}" << EOF
            <div class="summary-cards">
                <div class="card info">
                    <h3>Total Tests</h3>
                    <div class="value">${TOTAL_TESTS}</div>
                </div>
EOF

# Calculate totals from all summary files
TOTAL_CALLS=0
SUCCESSFUL_CALLS=0
FAILED_CALLS=0

for SUMMARY in "${RESULTS_DIR}"/stats/*_summary.json; do
    if [ -f "$SUMMARY" ]; then
        CALLS=$(python3 -c "import json; print(json.load(open('$SUMMARY')).get('total_calls', 0))" 2>/dev/null || echo "0")
        SUCCESS=$(python3 -c "import json; print(json.load(open('$SUMMARY')).get('successful_calls', 0))" 2>/dev/null || echo "0")
        FAIL=$(python3 -c "import json; print(json.load(open('$SUMMARY')).get('failed_calls', 0))" 2>/dev/null || echo "0")
        
        TOTAL_CALLS=$((TOTAL_CALLS + CALLS))
        SUCCESSFUL_CALLS=$((SUCCESSFUL_CALLS + SUCCESS))
        FAILED_CALLS=$((FAILED_CALLS + FAIL))
    fi
done

SUCCESS_RATE="0"
if [ ${TOTAL_CALLS} -gt 0 ]; then
    SUCCESS_RATE=$(awk "BEGIN {printf \"%.1f\", (${SUCCESSFUL_CALLS} / ${TOTAL_CALLS}) * 100}")
fi

cat >> "${REPORT_FILE}" << EOF
                <div class="card success">
                    <h3>Successful Calls</h3>
                    <div class="value">${SUCCESSFUL_CALLS}</div>
                </div>
                <div class="card error">
                    <h3>Failed Calls</h3>
                    <div class="value">${FAILED_CALLS}</div>
                </div>
                <div class="card info">
                    <h3>Success Rate</h3>
                    <div class="value">${SUCCESS_RATE}%</div>
                </div>
            </div>
            
            <div class="section">
                <h2>Overall Success Rate</h2>
                <div class="progress-bar">
                    <div class="progress-fill" style="width: ${SUCCESS_RATE}%">${SUCCESS_RATE}%</div>
                </div>
            </div>
            
            <div class="section">
                <h2>Test Results</h2>
EOF

# Add individual test results
for SUMMARY in "${RESULTS_DIR}"/stats/*_summary.json; do
    if [ -f "$SUMMARY" ]; then
        TEST_NAME=$(basename "$SUMMARY" _summary.json)
        
        # Extract metrics
        T_CALLS=$(python3 -c "import json; print(json.load(open('$SUMMARY')).get('total_calls', 0))" 2>/dev/null || echo "0")
        S_CALLS=$(python3 -c "import json; print(json.load(open('$SUMMARY')).get('successful_calls', 0))" 2>/dev/null || echo "0")
        F_CALLS=$(python3 -c "import json; print(json.load(open('$SUMMARY')).get('failed_calls', 0))" 2>/dev/null || echo "0")
        AVG_RT=$(python3 -c "import json; print(json.load(open('$SUMMARY')).get('avg_response_time', 0))" 2>/dev/null || echo "0")
        CPS=$(python3 -c "import json; print(json.load(open('$SUMMARY')).get('cps_achieved', 0))" 2>/dev/null || echo "0")
        
        # Determine status
        STATUS="pass"
        STATUS_CLASS="status-pass"
        if [ ${F_CALLS} -gt 0 ]; then
            FAIL_PCT=$(awk "BEGIN {printf \"%.1f\", (${F_CALLS} / ${T_CALLS}) * 100}")
            if (( $(echo "${FAIL_PCT} > 10" | bc -l) )); then
                STATUS="fail"
                STATUS_CLASS="status-fail"
            elif (( $(echo "${FAIL_PCT} > 5" | bc -l) )); then
                STATUS="warn"
                STATUS_CLASS="status-warn"
            fi
        fi
        
        cat >> "${REPORT_FILE}" << EOF
                <div class="test-result">
                    <h3>${TEST_NAME} <span class="status-badge ${STATUS_CLASS}">${STATUS}</span></h3>
                    <div class="metrics">
                        <div class="metric">
                            <div class="metric-label">Total Calls</div>
                            <div class="metric-value">${T_CALLS}</div>
                        </div>
                        <div class="metric">
                            <div class="metric-label">Successful</div>
                            <div class="metric-value">${S_CALLS}</div>
                        </div>
                        <div class="metric">
                            <div class="metric-label">Failed</div>
                            <div class="metric-value">${F_CALLS}</div>
                        </div>
                        <div class="metric">
                            <div class="metric-label">Avg Response Time</div>
                            <div class="metric-value">${AVG_RT}ms</div>
                        </div>
                        <div class="metric">
                            <div class="metric-label">CPS Achieved</div>
                            <div class="metric-value">${CPS}</div>
                        </div>
                    </div>
                </div>
EOF
    fi
done

# Close HTML
cat >> "${REPORT_FILE}" << EOF
            </div>
        </div>
        
        <div class="footer">
            <p>Generated by SIPP Test Framework | $(date)</p>
            <p>Test Data Location: ${RESULTS_DIR}</p>
        </div>
    </div>
</body>
</html>
EOF

echo "Report generated successfully: ${REPORT_FILE}"
echo ""
echo "View report with:"
echo "  open ${REPORT_FILE}   # macOS"
echo "  xdg-open ${REPORT_FILE}   # Linux"
