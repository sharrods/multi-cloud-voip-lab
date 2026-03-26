# 305 Redirect Testing Guide

This framework supports **two modes** for testing 305 redirects:

## Mode 1: Complete Test with SIPP UAS (Self-Contained)

Use this when you want a complete end-to-end test where SIPP provides both the UAC and UAS.

```bash
# Full redirect test (SIPP provides both UAC and UAS)
just test-redirect 127.0.0.1:5060 5 50
```

**What happens:**
1. SIPP starts a UAS on port 5070 that sends 305 responses
2. SIPP UAC sends INVITEs to 127.0.0.1:5060
3. UAS responds with `305 Use Proxy` and Contact header
4. UAC extracts redirect target from Contact header
5. UAC sends new INVITE to redirect target
6. Call completes normally

**Use case:** Testing your SIP proxy/routing logic when it's sitting between the UAC and UAS.

---

## Mode 2: Test Against External/Remote UAS (Your Real SBC)

**This is what you asked about!** Use this when your **real SBC/UAS** sends the 305 responses.

```bash
# Test against YOUR SBC that sends 305 responses
just test-redirect-external 192.168.1.100:5060 5 50
```

**What happens:**
1. SIPP UAC sends INVITEs to your SBC at 192.168.1.100:5060
2. Your SBC/UAS responds with `305 Use Proxy` and Contact header
3. SIPP UAC automatically extracts the redirect target from Contact
4. SIPP UAC sends new INVITE to the redirect target
5. Call completes normally

**Use case:** Testing a real SBC's redirect behavior in production or lab environments.

---

## Configuration for External Testing

### Your SBC Must Send:

```
SIP/2.0 305 Use Proxy
Via: SIP/2.0/UDP 192.168.1.50:5060;branch=z9hG4bK-123
From: <sip:caller@192.168.1.50:5060>;tag=SIPpTag001
To: <sip:1000@192.168.1.100:5060>;tag=as7d8f9g
Call-ID: 1-123@192.168.1.50
CSeq: 1 INVITE
Contact: <sip:1000@192.168.1.200:5060>
Content-Length: 0
```

**Key requirement:** The `Contact` header must contain the redirect target.

### Contact Header Formats Supported

The UAC handles multiple Contact header formats:

```
# Format 1: Full user@host:port
Contact: <sip:1000@192.168.1.200:5060>

# Format 2: host:port (no user)
Contact: <sip:192.168.1.200:5060>

# Format 3: With parameters
Contact: <sip:1000@192.168.1.200:5060;transport=udp>

# Format 4: Default port (5060)
Contact: <sip:1000@192.168.1.200>
```

---

## Advanced Usage Examples

### Test with Custom Rate and Duration

```bash
# High-rate redirect testing
just test-redirect-external 192.168.1.100:5060 20 1000

# Low-rate, long duration
just test-redirect-external 192.168.1.100:5060 2 500
```

### Run Against Different SBC Ports

```bash
# Test against SBC on non-standard port
just test-redirect-external 192.168.1.100:5080 5 50
```

### Test Multiple Redirect Targets

Configure your SBC to redirect to different targets, then:

```bash
# Run test and analyze where calls were redirected
just test-redirect-external 192.168.1.100:5060 10 100

# View the logs to see all redirect targets
cat logs/functional/redirect_external_*/messages.log | grep "Contact:"
```

---

## Direct SIPP Command (Manual Testing)

If you want to run SIPP directly without the justfile:

```bash
# Using the standalone UAC scenario
sipp 192.168.1.100:5060 \
  -sf scenarios/redirect/redirect_uac_standalone.xml \
  -r 5 \
  -m 50 \
  -s 1000 \
  -trace_msg -message_file redirect_messages.log \
  -trace_screen \
  -trace_err
```

**Parameters:**
- `-r 5` = 5 calls per second
- `-m 50` = 50 total calls
- `-s 1000` = Service/called number (can be any value)

---

## Verifying Redirect Behavior

### Check Logs for Redirect Flow

After running the test, examine the logs:

```bash
# View message flow
cat logs/functional/redirect_external_*/messages.log

# Look for 305 responses
grep "305 Use Proxy" logs/functional/redirect_external_*/messages.log

# Find redirect targets
grep "Contact:" logs/functional/redirect_external_*/messages.log | grep "305"

# Verify redirected INVITEs were sent
grep "INVITE.*redirect" logs/functional/redirect_external_*/messages.log
```

### Expected Log Sequence

You should see this flow in the logs:

```
1. Sent INVITE to original target (your SBC)
2. Recv 305 Use Proxy from SBC
3. Extracted Contact: <sip:target@host:port>
4. Sent ACK to 305
5. Sent new INVITE to redirect target
6. Recv 100 Trying from redirect target
7. Recv 180 Ringing from redirect target
8. Recv 200 OK from redirect target
9. Sent ACK to 200 OK
10. [Call holds for 5 seconds]
11. Sent BYE to redirect target
12. Recv 200 OK for BYE
```

---

## Real-World Testing Scenarios

### Scenario 1: Load Balancer with 305 Redirects

Your load balancer sends 305 to distribute calls across multiple SBCs:

```bash
# Test load balancer redirect behavior
just test-redirect-external load-balancer.example.com:5060 10 200

# Analyze which SBCs received redirected calls
grep "Redirect to:" logs/functional/redirect_external_*/screen.log
```

### Scenario 2: Geographic Routing

Your SBC redirects based on geography:

```bash
# Test geo-routing redirects
just test-redirect-external geo-router.example.com:5060 5 100

# View all redirect targets
cat logs/functional/redirect_external_*/messages.log | \
  grep -A 1 "305 Use Proxy" | \
  grep "Contact:" | \
  sort | uniq -c
```

### Scenario 3: Capacity Testing with Redirects

Test how your redirect system handles high CPS:

```bash
# Gradually increase rate
just test-redirect-external 192.168.1.100:5060 10 500
just test-redirect-external 192.168.1.100:5060 20 1000
just test-redirect-external 192.168.1.100:5060 50 2000

# Check for failures at high rates
grep "ERROR" logs/functional/redirect_external_*/error.log
```

---

## Troubleshooting

### Problem: UAC doesn't follow redirect

**Check:**
1. Is your SBC sending a valid Contact header in the 305?
2. Is the Contact header format supported? (see formats above)
3. Check error log: `cat logs/functional/redirect_external_*/error.log`

**Debug:**
```bash
# Run with verbose output
sipp 192.168.1.100:5060 \
  -sf scenarios/redirect/redirect_uac_standalone.xml \
  -trace_screen \
  -r 1 -m 1
```

### Problem: Redirect target unreachable

**Symptoms:** UAC sends INVITE to redirect target but no response

**Check:**
1. Is the redirect target (from Contact header) routable?
2. Is the redirect target listening on the correct port?
3. Check network connectivity: `telnet <redirect_target> <port>`

**Debug:**
```bash
# Capture packets
sudo tcpdump -i any -s 0 -w redirect_test.pcap port 5060

# Run test
just test-redirect-external 192.168.1.100:5060 1 1

# Analyze with Wireshark
wireshark redirect_test.pcap
```

### Problem: 305 timeout

**Symptoms:** UAC times out waiting for 305 response

**Check:**
1. Is your SBC configured to send 305 for these calls?
2. Is the SBC reachable? `sipp 192.168.1.100:5060 -sn uac -m 1`
3. Check SBC logs for errors

---

## Integration with Regression Testing

Add redirect testing to your regression suite:

Edit `justfile`:

```makefile
# Custom regression with external redirect testing
test-regression-with-redirect target="192.168.1.100:5060":
    @echo "Running regression with redirect tests..."
    @just test-basic-uac "{{target}}" "10" "100"
    @just test-redirect-external "{{target}}" "5" "50"
    @just test-auth-uac "{{target}}" "testuser" "testpass"
    @bash scripts/collect_stats.sh "regression" "{{TIMESTAMP}}"
    @bash scripts/generate_report.sh "regression" "{{TIMESTAMP}}"
```

Run it:
```bash
just test-regression-with-redirect 192.168.1.100:5060
```

---

## Performance Metrics

The redirect UAC tracks these metrics:

- **Total redirect attempts:** How many 305 responses received
- **Successful redirects:** Calls that completed after redirect
- **Failed redirects:** Calls that failed after receiving 305
- **Average redirect time:** Time from initial INVITE to redirected call answer
- **Response time:** Time to receive 305 response

View metrics:
```bash
# After test completes
cat results/functional/*/stats/*_summary.json
```

---

## Summary

**Use `test-redirect-external` when:**
- Testing real SBC redirect behavior
- Your SBC sends 305 responses
- Validating redirect target selection logic
- Load testing redirect systems
- Integration testing with actual network equipment

**The standalone UAC will automatically:**
✅ Send INVITE to your SBC  
✅ Parse 305 response  
✅ Extract Contact header  
✅ Send new INVITE to redirect target  
✅ Complete the call  
✅ Log everything  
✅ Generate statistics  

No manual intervention needed - fully automated!
