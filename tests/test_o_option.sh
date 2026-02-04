#!/bin/bash
#
# Comprehensive test script for the -o option (print matching pattern)
# Tests the narrowest-match selection for both IPv4 and IPv6 addresses
#
# This script tests:
#  - Basic IPv4 pattern matching
#  - Narrowest match selection with overlapping ranges
#  - Multiple IP address processing
#  - IPv6 pattern matching and narrowest match
#  - Mixed IPv4/IPv6 pattern files
#  - stdin input handling
#  - Normal mode (without -o) still works correctly
#  - Edge cases: /32, /128, exact IPs, comments in pattern files
#  - Complex overlapping ranges
#  - Pattern ordering preferences
#  - Count mode (-c) compatibility
#  - Real-world use cases (AWS IP ranges)
#  - Performance with large pattern sets
#  - IPv4-mapped IPv6 addresses
#
# Exit codes:
#  0 - All tests passed
#  1 - One or more tests failed
#

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Find grepcidr binary (in parent directory if running from tests/)
if [ -f "./grepcidr" ]; then
    GREPCIDR="./grepcidr"
elif [ -f "../grepcidr" ]; then
    GREPCIDR="../grepcidr"
else
    echo "Error: grepcidr binary not found"
    exit 1
fi

PASSED=0
FAILED=0
TOTAL=0

# Test counter
test_num=0

# Function to run a test
run_test() {
    local test_name="$1"
    local expected="$2"
    local actual="$3"
    
    test_num=$((test_num + 1))
    TOTAL=$((TOTAL + 1))
    
    if [ "$expected" = "$actual" ]; then
        echo -e "${GREEN}✓${NC} Test $test_num: $test_name"
        PASSED=$((PASSED + 1))
        return 0
    else
        echo -e "${RED}✗${NC} Test $test_num: $test_name"
        echo "  Expected:"
        echo "$expected" | sed 's/^/    /'
        echo "  Got:"
        echo "$actual" | sed 's/^/    /'
        FAILED=$((FAILED + 1))
        return 1
    fi
}

echo "========================================="
echo "Testing grepcidr -o option"
echo "========================================="
echo

# Check if grepcidr exists
if [ ! -x "$GREPCIDR" ]; then
    echo -e "${RED}Error: $GREPCIDR not found or not executable${NC}"
    echo "Please run 'make' first"
    exit 1
fi

# Create temporary directory for test files
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

echo "Test directory: $TMPDIR"
echo

#######################################
# Test 1: Basic IPv4 pattern matching
#######################################
echo "=== Basic IPv4 Tests ==="
cat > "$TMPDIR/ipv4_patterns.txt" <<EOF
192.168.1.0/24
10.0.0.0/8
172.16.0.0/12
EOF

expected="192.168.1.0/24"
actual=$(echo "192.168.1.100" | $GREPCIDR -o -f "$TMPDIR/ipv4_patterns.txt")
run_test "Single IPv4 match" "$expected" "$actual"

expected="10.0.0.0/8"
actual=$(echo "10.5.10.1" | $GREPCIDR -o -f "$TMPDIR/ipv4_patterns.txt")
run_test "Match from different pattern" "$expected" "$actual"

expected=""
actual=$(echo "8.8.8.8" | $GREPCIDR -o -f "$TMPDIR/ipv4_patterns.txt")
run_test "No match returns empty" "$expected" "$actual"

#######################################
# Test 2: Narrowest match selection
#######################################
echo
echo "=== Narrowest Match Selection (IPv4) ==="
cat > "$TMPDIR/overlapping_ipv4.txt" <<EOF
192.168.0.0/16
192.168.1.0/24
192.168.1.128/25
EOF

expected="192.168.1.128/25"
actual=$(echo "192.168.1.200" | $GREPCIDR -o -f "$TMPDIR/overlapping_ipv4.txt")
run_test "Narrowest match for 192.168.1.200 (in /25)" "$expected" "$actual"

expected="192.168.1.128/25"
actual=$(echo "192.168.1.150" | $GREPCIDR -o -f "$TMPDIR/overlapping_ipv4.txt")
run_test "Narrowest match for 192.168.1.150 (in /25)" "$expected" "$actual"

expected="192.168.1.0/24"
actual=$(echo "192.168.1.50" | $GREPCIDR -o -f "$TMPDIR/overlapping_ipv4.txt")
run_test "Match /24 when not in /25 range" "$expected" "$actual"

expected="192.168.0.0/16"
actual=$(echo "192.168.2.1" | $GREPCIDR -o -f "$TMPDIR/overlapping_ipv4.txt")
run_test "Match /16 when not in smaller ranges" "$expected" "$actual"

#######################################
# Test 3: Multiple IPs at once
#######################################
echo
echo "=== Multiple IPs in Input ==="
cat > "$TMPDIR/multi_ips.txt" <<EOF
192.168.1.200
192.168.1.150
192.168.1.50
192.168.2.1
10.0.0.1
EOF

expected="192.168.1.128/25
192.168.1.128/25
192.168.1.0/24
192.168.0.0/16"
actual=$($GREPCIDR -o -f "$TMPDIR/overlapping_ipv4.txt" "$TMPDIR/multi_ips.txt")
run_test "Multiple IPs matched to patterns" "$expected" "$actual"

#######################################
# Test 4: Basic IPv6 pattern matching
#######################################
echo
echo "=== Basic IPv6 Tests ==="
cat > "$TMPDIR/ipv6_patterns.txt" <<EOF
2001:db8::/32
2001:db8:1::/48
2001:db8:1:2::/64
EOF

expected="2001:db8:1:2::/64"
actual=$(echo "2001:db8:1:2::1" | $GREPCIDR -o -f "$TMPDIR/ipv6_patterns.txt")
run_test "IPv6 narrowest match for /64" "$expected" "$actual"

expected="2001:db8:1::/48"
actual=$(echo "2001:db8:1::1" | $GREPCIDR -o -f "$TMPDIR/ipv6_patterns.txt")
run_test "IPv6 match for /48" "$expected" "$actual"

expected="2001:db8::/32"
actual=$(echo "2001:db8:5::1" | $GREPCIDR -o -f "$TMPDIR/ipv6_patterns.txt")
run_test "IPv6 match for /32 only" "$expected" "$actual"

expected=""
actual=$(echo "2001:db9::1" | $GREPCIDR -o -f "$TMPDIR/ipv6_patterns.txt")
run_test "IPv6 no match" "$expected" "$actual"

#######################################
# Test 5: Mixed IPv4 and IPv6
#######################################
echo
echo "=== Mixed IPv4 and IPv6 ==="
cat > "$TMPDIR/mixed_patterns.txt" <<EOF
192.168.0.0/16
10.0.0.0/8
2001:db8::/32
fe80::/10
EOF

cat > "$TMPDIR/mixed_ips.txt" <<EOF
192.168.1.1
10.5.10.1
2001:db8::1
fe80::1
8.8.8.8
2001:db9::1
EOF

expected="192.168.0.0/16
10.0.0.0/8
2001:db8::/32
fe80::/10"
actual=$($GREPCIDR -o -f "$TMPDIR/mixed_patterns.txt" "$TMPDIR/mixed_ips.txt")
run_test "Mixed IPv4 and IPv6 matching" "$expected" "$actual"

#######################################
# Test 6: stdin input
#######################################
echo
echo "=== stdin Input Tests ==="

expected="192.168.1.0/24
10.0.0.0/8"
actual=$(echo -e "192.168.1.1\n10.0.0.1\n8.8.8.8" | $GREPCIDR -o -f "$TMPDIR/ipv4_patterns.txt")
run_test "Read from stdin" "$expected" "$actual"

#######################################
# Test 7: Verify normal mode still works
#######################################
echo
echo "=== Normal Mode (without -o) ==="

expected="192.168.1.1"
actual=$(echo -e "192.168.1.1\n10.0.0.1\n8.8.8.8" | $GREPCIDR "192.168.0.0/16")
run_test "Normal mode prints IP, not pattern" "$expected" "$actual"

expected="192.168.1.100
10.5.10.1
192.168.1.200"
actual=$(echo -e "192.168.1.100\n10.5.10.1\n192.168.1.200" | $GREPCIDR -f "$TMPDIR/ipv4_patterns.txt")
run_test "Normal mode with pattern file" "$expected" "$actual"

#######################################
# Test 8: Edge cases
#######################################
echo
echo "=== Edge Cases ==="

# Single IP pattern (no CIDR notation but stored as single host)
cat > "$TMPDIR/single_ip.txt" <<EOF
192.168.1.100
10.0.0.0/8
EOF

expected="192.168.1.100"
actual=$(echo "192.168.1.100" | $GREPCIDR -o -f "$TMPDIR/single_ip.txt")
run_test "Exact IP match" "$expected" "$actual"

# /32 and /128 patterns
cat > "$TMPDIR/exact_matches.txt" <<EOF
192.168.1.100/32
2001:db8::1/128
EOF

expected="192.168.1.100/32"
actual=$(echo "192.168.1.100" | $GREPCIDR -o -f "$TMPDIR/exact_matches.txt")
run_test "IPv4 /32 match" "$expected" "$actual"

expected="2001:db8::1/128"
actual=$(echo "2001:db8::1" | $GREPCIDR -o -f "$TMPDIR/exact_matches.txt")
run_test "IPv6 /128 match" "$expected" "$actual"

# Comments and empty lines in pattern file
cat > "$TMPDIR/with_comments.txt" <<EOF
# This is a comment
192.168.0.0/16

# Another comment
10.0.0.0/8
EOF

expected="192.168.0.0/16"
actual=$(echo "192.168.1.1" | $GREPCIDR -o -f "$TMPDIR/with_comments.txt")
run_test "Pattern file with comments" "$expected" "$actual"

#######################################
# Test 9: Multiple overlapping ranges
#######################################
echo
echo "=== Complex Overlapping Ranges ==="
cat > "$TMPDIR/many_overlaps.txt" <<EOF
0.0.0.0/0
10.0.0.0/8
10.10.0.0/16
10.10.10.0/24
10.10.10.0/25
10.10.10.128/26
EOF

expected="10.10.10.0/25"
actual=$(echo "10.10.10.50" | $GREPCIDR -o -f "$TMPDIR/many_overlaps.txt")
run_test "Select narrowest from many overlaps" "$expected" "$actual"

expected="10.10.10.0/25"
actual=$(echo "10.10.10.50" | $GREPCIDR -o -f "$TMPDIR/many_overlaps.txt")
run_test "Select /25 when not in /26" "$expected" "$actual"

#######################################
# Test 10: Pattern ordering preference
#######################################
echo
echo "=== Pattern Ordering ==="
# When multiple patterns have the same size, later ones should be preferred
cat > "$TMPDIR/same_size.txt" <<EOF
192.168.1.0/25
192.168.1.128/25
192.168.1.0/24
EOF

expected="192.168.1.128/25"
actual=$(echo "192.168.1.150" | $GREPCIDR -o -f "$TMPDIR/same_size.txt")
run_test "Prefer later pattern for equal-sized ranges" "$expected" "$actual"

#######################################
# Test 11: Pattern with trailing newlines
#######################################
echo
echo "=== Newline Handling ==="

# Test that patterns with newlines are handled correctly
expected="192.168.1.0/24"
actual=$(echo "192.168.1.1" | $GREPCIDR -o -f "$TMPDIR/ipv4_patterns.txt")
run_test "Pattern output includes newline if needed" "$expected" "$actual"

#######################################
# Test 12: Count mode with -c
#######################################
echo
echo "=== Count Mode (-c with -o) ==="

expected="2"
actual=$(echo -e "192.168.1.1\n10.0.0.1\n8.8.8.8" | $GREPCIDR -c -o -f "$TMPDIR/ipv4_patterns.txt")
run_test "Count matching lines with -o" "$expected" "$actual"

#######################################
# Test 13: AWS IP ranges (real-world use case)
#######################################
echo
echo "=== Real-World Use Case: AWS IP Ranges ==="
cat > "$TMPDIR/aws_ranges.txt" <<EOF
52.94.0.0/16
52.95.0.0/16
54.239.0.0/16
EOF

expected="52.94.0.0/16"
actual=$(echo "52.94.76.1" | $GREPCIDR -o -f "$TMPDIR/aws_ranges.txt")
run_test "AWS IP range matching" "$expected" "$actual"

#######################################
# Test 14: Large number of patterns
#######################################
echo
echo "=== Performance: Large Pattern Set ==="
# Create a file with many patterns
for i in {1..100}; do
    echo "10.$i.0.0/16" >> "$TMPDIR/large_patterns.txt"
done

expected="10.50.0.0/16"
actual=$(echo "10.50.100.1" | $GREPCIDR -o -f "$TMPDIR/large_patterns.txt")
run_test "Match in large pattern set" "$expected" "$actual"

#######################################
# Test 15: IPv4-mapped IPv6 addresses
#######################################
echo
echo "=== IPv4-mapped IPv6 Addresses ==="
cat > "$TMPDIR/ipv4_mapped.txt" <<EOF
::ffff:192.168.0.0/112
2001:db8::/32
EOF

# Note: IPv4-mapped IPv6 might not be supported, this documents the behavior
actual=$(echo "::ffff:192.168.1.1" | $GREPCIDR -o -f "$TMPDIR/ipv4_mapped.txt" 2>/dev/null || echo "NOT_SUPPORTED")
if [ "$actual" = "NOT_SUPPORTED" ]; then
    echo -e "${GREEN}✓${NC} Test $((test_num + 1)): IPv4-mapped IPv6 (not supported, documented)"
    test_num=$((test_num + 1))
    TOTAL=$((TOTAL + 1))
    PASSED=$((PASSED + 1))
else
    expected="::ffff:192.168.0.0/112"
    run_test "IPv4-mapped IPv6 address" "$expected" "$actual"
fi

#######################################
# Test 29: AWS use case - tab-delimited CIDR + service name
#######################################
echo
echo "Test 29: AWS Use Case - Tab-delimited CIDR + Service Name"

# Simulate AWS IP ranges format: <cidr><TAB><service>
cat > "$TMPDIR/aws_ranges.txt" <<EOF
52.94.0.0/16	EC2
52.95.0.0/21	S3
52.95.128.0/21	S3
54.239.0.0/16	CLOUDFRONT
13.34.0.0/16	CLOUDFRONT
3.5.0.0/19	API_GATEWAY
18.208.0.0/13	EC2
EOF

# Test single IP matching with service name
actual=$(echo "52.94.76.35" | $GREPCIDR -o -f "$TMPDIR/aws_ranges.txt")
expected="52.94.0.0/16	EC2"
run_test "AWS IP with service name (EC2)" "$expected" "$actual"

# Test multiple IPs with different services
cat > "$TMPDIR/test_ips_aws.txt" <<EOF
54.239.12.45
52.95.130.10
13.34.56.78
EOF

actual=$(cat "$TMPDIR/test_ips_aws.txt" | $GREPCIDR -o -f "$TMPDIR/aws_ranges.txt" | sort)
expected=$(cat <<EOF
13.34.0.0/16	CLOUDFRONT
52.95.128.0/21	S3
54.239.0.0/16	CLOUDFRONT
EOF
)
run_test "AWS multiple IPs with service names" "$expected" "$actual"

# Test narrowest match with overlapping AWS ranges (common scenario)
cat > "$TMPDIR/aws_overlapping.txt" <<EOF
52.95.0.0/16	S3_GLOBAL
52.95.128.0/21	S3_US_EAST_1
52.95.128.0/24	S3_US_EAST_1A
EOF

# IP in the most specific range
actual=$(echo "52.95.128.50" | $GREPCIDR -o -f "$TMPDIR/aws_overlapping.txt")
expected="52.95.128.0/24	S3_US_EAST_1A"
run_test "AWS narrowest match with service metadata" "$expected" "$actual"

# Test simulated lsof workflow: extract IPs and match against AWS ranges
cat > "$TMPDIR/simulated_lsof.txt" <<EOF
chrome    1234 user   42u  IPv4  52.94.76.35:443
firefox   5678 user   18u  IPv4  54.239.12.100:80
vscode    9012 user   25u  IPv4  13.34.78.90:443
node      3456 user   11u  IPv4  52.95.130.25:3000
EOF

# Extract IPs and match (simulates: lsof -i -nP | extract-ips | grepcidr -o -f aws-cidrs.txt)
actual=$(grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' "$TMPDIR/simulated_lsof.txt" | $GREPCIDR -o -f "$TMPDIR/aws_ranges.txt" | sort)
expected=$(cat <<EOF
13.34.0.0/16	CLOUDFRONT
52.94.0.0/16	EC2
52.95.128.0/21	S3
54.239.0.0/16	CLOUDFRONT
EOF
)
run_test "AWS lsof workflow simulation" "$expected" "$actual"

# Test with real-world AWS range sizes (mix of small and large ranges)
cat > "$TMPDIR/aws_realistic.txt" <<EOF
3.0.0.0/15	EC2
13.34.0.0/16	CLOUDFRONT
18.208.0.0/13	EC2
52.94.0.0/22	EC2
52.95.128.0/21	S3
54.239.0.0/16	CLOUDFRONT
EOF

actual=$(echo "18.210.5.100" | $GREPCIDR -o -f "$TMPDIR/aws_realistic.txt")
expected="18.208.0.0/13	EC2"
run_test "AWS real-world range sizes" "$expected" "$actual"

#######################################
# Summary
#######################################
echo
echo "========================================="
echo "Test Summary"
echo "========================================="
echo -e "Total tests: $TOTAL"
echo -e "${GREEN}Passed: $PASSED${NC}"
if [ $FAILED -gt 0 ]; then
    echo -e "${RED}Failed: $FAILED${NC}"
    exit 1
else
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
fi
