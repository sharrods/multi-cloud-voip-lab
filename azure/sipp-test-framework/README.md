# SIPP Test Framework

A comprehensive, modular SIP testing framework using SIPP with automated logging, statistics collection, and reporting.

## 🚀 Quick Start

### Installation

```bash
# Clone or download the framework
cd sipp-test-framework

# Initialize environment
just init

# Validate setup
just validate
```

### Prerequisites

- SIPP installed (`sipp` command available)
- Just task runner (`brew install just` or `cargo install just`)
- Python 3.x
- Bash 4.0+

## 📁 Directory Structure

```
sipp-test-framework/
├── justfile                    # Main task orchestration
├── configs/
│   ├── test_config.env        # Test environment configuration
│   └── sbc_targets.conf       # SBC target definitions
├── scenarios/                  # SIPP XML scenarios
│   ├── basic/                 # Basic call scenarios
│   │   ├── basic_uac.xml
│   │   ├── basic_uas.xml
│   │   └── auth_uac.xml
│   ├── redirect/              # Redirect scenarios
│   │   ├── redirect_uas_305.xml
│   │   └── redirect_uac.xml
│   ├── advanced/              # Advanced scenarios
│   │   ├── prack_flow.xml
│   │   ├── update_flow.xml
│   │   └── reinvite_flow.xml
│   └── error/                 # Error scenarios
│       ├── error_4xx.xml
│       ├── error_5xx.xml
│       └── timeout_no_response.xml
├── scripts/                    # Helper scripts
│   ├── justfile               # Script-specific tasks
│   ├── collect_stats.sh       # Stats collection
│   ├── parse_logs.sh          # Log parsing
│   ├── generate_report.sh     # HTML report generation
│   ├── run_cps_test.sh        # CPS testing
│   └── run_capacity_test.sh   # Capacity testing
├── logs/                       # Test logs (organized by type)
│   ├── functional/
│   ├── regression/
│   ├── capacity/
│   ├── cps/
│   └── error/
├── results/                    # Test results (organized by type)
│   ├── functional/
│   ├── regression/
│   ├── capacity/
│   ├── cps/
│   └── error/
└── reports/                    # HTML test reports
```

## 🎯 Usage Examples

### Basic Commands

```bash
# List all available commands
just

# List all scenarios
just list-scenarios

# Run a specific scenario by name
just run-scenario basic_uac 192.168.1.100:5060 10 60

# Clean logs
just clean

# Clean everything
just clean-all
```

### Functional Testing

```bash
# Basic UAC test (caller)
just test-basic-uac 192.168.1.100:5060 10 100

# Basic UAS test (receiver) - runs on specified port
just test-basic-uas 5070

# Authenticated UAC test
just test-auth-uac 192.168.1.100:5060 myuser mypass
```

### 305 Redirect Testing

The framework includes a complete 305 redirect implementation:

```bash
# Test 305 redirect flow
# This starts a UAS that sends 305 responses with Contact header
# Then sends INVITEs that follow the redirect
just test-redirect 192.168.1.100:5060 5 50

# Or run redirect UAS separately (for testing with external UAC)
just run-redirect-uas 5070
```

**How it works:**
1. Redirect UAS receives INVITE
2. UAS responds with `305 Use Proxy` and Contact header pointing to redirect target
3. UAC extracts Contact header from 305 response
4. UAC sends new INVITE to the redirect target
5. Call completes normally with redirected target

### Error Testing

```bash
# Test various error responses (4xx, 5xx, 6xx)
just test-errors 192.168.1.100:5060

# Test timeout scenarios
just test-timeouts 192.168.1.100:5060

# Test malformed messages
just test-malformed 192.168.1.100:5060

# Run complete error test suite
just test-all-errors 192.168.1.100:5060
```

### Performance Testing

```bash
# CPS (Calls Per Second) ramp test
# Ramps from 0 to 100 CPS in steps of 10
just test-cps 192.168.1.100:5060 100 10 300

# Sustained capacity test
# 50 CPS for 1 hour with max 1000 concurrent calls
just test-capacity 192.168.1.100:5060 50 3600 1000

# Stress test - push to failure
just test-stress 192.168.1.100:5060 10 500
```

### Regression Testing

```bash
# Full regression suite (comprehensive)
just test-regression 192.168.1.100:5060

# Quick regression (subset of tests)
just test-regression-quick 192.168.1.100:5060
```

**Full regression includes:**
- Basic UAC test (100 calls at 10 CPS)
- Authentication test
- 305 Redirect test
- Error response tests (4xx, 5xx, 6xx)
- CPS ramp test (up to 50 CPS)
- Automated reporting

### Advanced Scenarios

```bash
# PRACK (Reliable Provisional Responses)
just test-prack 192.168.1.100:5060 5 50

# UPDATE method test
just test-update 192.168.1.100:5060 5 50

# Re-INVITE (session modification)
just test-reinvite 192.168.1.100:5060 5 50

# Call transfer (REFER)
just test-refer 192.168.1.100:5060 3 30

# Codec negotiation tests
just test-codecs 192.168.1.100:5060

# RTP media test
just test-rtp 192.168.1.100:5060 10 50
```

### Reporting

```bash
# Generate HTML report for a test type
just report regression 20241129_143022

# View latest report for test type
just view-report regression

# Show statistics summary
just stats

# Archive old results (older than 30 days)
just archive 30
```

## 🔧 Configuration

### Test Environment Setup

Edit `configs/test_config.env`:

```bash
# SBC Configuration
DEFAULT_TARGET="192.168.1.100:5060"
REDIRECT_TARGET="192.168.1.200"
REDIRECT_PORT="5060"

# Test Parameters
DEFAULT_DURATION="60"
DEFAULT_RATE="10"
DEFAULT_CALLS="100"

# Authentication
SIP_USERNAME="testuser"
SIP_PASSWORD="testpass"

# Thresholds
MAX_FAILURE_RATE="5.0"
MIN_SUCCESS_RATE="95.0"
```

### Adding Custom Scenarios

1. Create XML scenario in `scenarios/` directory:

```xml
<?xml version="1.0" encoding="ISO-8859-1" ?>
<!DOCTYPE scenario SYSTEM "sipp.dtd">
<scenario name="My Custom Test">
  <!-- Your scenario here -->
</scenario>
```

2. Add justfile recipe:

```makefile
# My custom test
test-custom target="127.0.0.1:5060" rate="5":
    @just run-scenario "my_custom" "{{target}}" "{{rate}}" "60"
```

3. Run it:

```bash
just test-custom 192.168.1.100:5060 10
```

## 📊 Output & Results

### Log Organization

Each test run creates organized logs with timestamps:

```
logs/
└── functional/
    └── basic_uac_20241129_143022/
        ├── messages.log      # SIP message traces
        ├── screen.log        # SIPP screen output
        ├── error.log         # Error messages
        └── stats.csv         # Call statistics
```

### Results Structure

```
results/
└── regression/
    └── 20241129_143022/
        ├── logs/             # Copied logs
        ├── stats/            # Parsed statistics
        │   ├── *_summary.json
        │   ├── *_errors.txt
        │   └── *_messages.txt
        └── summary.txt       # Overall summary
```

### HTML Reports

Reports are generated in `reports/` with:
- Summary cards (total calls, success rate, failures)
- Individual test results with metrics
- Visual progress bars
- Pass/Fail/Warning badges
- Responsive design

## 🎨 Customization

### Environment-Specific Testing

```bash
# Set environment
export TEST_ENV=production

# Configuration automatically adjusts based on TEST_ENV
just test-regression $SBC_PRIMARY
```

### Custom Test Suites

Create your own test suite by adding to `justfile`:

```makefile
# My custom test suite
test-my-suite target="127.0.0.1:5060":
    @echo "Running my custom test suite..."
    @just test-basic-uac "{{target}}" "20" "200"
    @just test-redirect "{{target}}" "10" "100"
    @just test-cps "{{target}}" "100" "10" "180"
    @bash scripts/generate_report.sh "custom" "{{TIMESTAMP}}"
```

## 📈 Best Practices

### VoIP Testing Best Practices

1. **Start Small**: Begin with low CPS (5-10) and gradually increase
2. **Monitor System**: Watch CPU, memory, and network on both SIPP and SBC
3. **Baseline Testing**: Establish baseline metrics before making changes
4. **Isolation**: Test one variable at a time
5. **Cool Down**: Allow system to stabilize between tests
6. **Log Everything**: Enable comprehensive logging for troubleshooting

### CPS Testing Strategy

```bash
# Phase 1: Establish baseline
just test-basic-uac $TARGET 10 100

# Phase 2: Find maximum CPS
just test-cps $TARGET 200 10 120

# Phase 3: Sustained load at 80% of max
# If max was 150 CPS, test at 120 CPS
just test-capacity $TARGET 120 3600 2000

# Phase 4: Stress test to find breaking point
just test-stress $TARGET 10 300
```

### Regression Testing Workflow

```bash
# Daily regression
0 2 * * * cd /path/to/framework && just test-regression-quick $TARGET

# Weekly full regression
0 2 * * 0 cd /path/to/framework && just test-regression $TARGET

# Archive monthly
0 3 1 * * cd /path/to/framework && just archive 30
```

## 🐛 Troubleshooting

### Common Issues

**SIPP not found:**
```bash
# Install SIPP
sudo apt-get install sipp  # Ubuntu/Debian
brew install sipp          # macOS
```

**Permission errors:**
```bash
# Make scripts executable
chmod +x scripts/*.sh
```

**Port conflicts:**
```bash
# Check for processes using port
sudo lsof -i :5060
```

### Debug Mode

Enable verbose output:

```bash
# Run with debug logging
SIPP_DEBUG=1 just test-basic-uac $TARGET
```

## 📚 Resources

- [SIPP Documentation](http://sipp.sourceforge.net/)
- [SIP RFC 3261](https://tools.ietf.org/html/rfc3261)
- [Just Manual](https://just.systems/man/en/)

## 🤝 Contributing

To extend the framework:

1. Add scenarios to `scenarios/` directory
2. Create helper scripts in `scripts/`
3. Add recipes to `justfile`
4. Update documentation

## 📝 License

MIT License - Use freely for testing and development
