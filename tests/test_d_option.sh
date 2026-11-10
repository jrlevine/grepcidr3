#!/bin/bash
#
# Test script for IP range matching in the input with -C/-D
# Tests that input lines containing IP ranges (start-end) are parsed
# as ranges and matched like CIDRs in the input:
#  -D: match if the search term overlaps any part of the input range
#  -C: match only if the search term covers the entire input range
#
# This script tests:
#  - -D overlap matching of input ranges (both directions)
#  - -C full-cover matching of input ranges
#  - No-flag behavior stays unchanged (endpoints matched as single IPs)
#  - Spaces around the dash, backward ranges
#  - Invalid ranges fall back to single-IP behavior
#  - Multiple ranges / mixed addresses on one line
#  - -c, -v, -o combinations
#  - Pattern files and multiple input files
#  - CIDR input behavior (-C/-D) unchanged
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
echo "Testing grepcidr -C/-D input range matching"
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
# -D: input range overlaps pattern
#######################################
echo "=== -D: overlap matching of input ranges ==="

expected="10.0.0.1-10.0.0.100"
actual=$(echo "10.0.0.1-10.0.0.100" | $GREPCIDR -D -h "10.0.0.50/32")
run_test "Input range contains /32 pattern (pattern in range)" "$expected" "$actual"

expected="10.0.0.1-10.0.0.100"
actual=$(echo "10.0.0.1-10.0.0.100" | $GREPCIDR -D -h "10.0.0.50-10.0.0.60")
run_test "Input range overlaps range pattern" "$expected" "$actual"

expected="10.0.0.1-10.0.0.100"
actual=$(echo "10.0.0.1-10.0.0.100" | $GREPCIDR -D -h "10.0.0.50")
run_test "Input range contains single-IP pattern" "$expected" "$actual"

expected="10.0.0.1-10.0.0.100"
actual=$(echo "10.0.0.1-10.0.0.100" | $GREPCIDR -D -h "10.0.0.0/8")
run_test "Input range fully inside pattern" "$expected" "$actual"

expected=""
actual=$(echo "10.0.0.1-10.0.0.100" | $GREPCIDR -D -h "192.168.0.0/16")
run_test "No overlap, no match" "$expected" "$actual"

expected="10.0.0.1 - 10.0.0.100"
actual=$(echo "10.0.0.1 - 10.0.0.100" | $GREPCIDR -D -h "10.0.0.50")
run_test "Spaces around dash" "$expected" "$actual"

expected="10.0.0.100-10.0.0.1"
actual=$(echo "10.0.0.100-10.0.0.1" | $GREPCIDR -D -h "10.0.0.50")
run_test "Backward range is normalized" "$expected" "$actual"

expected=$(printf '10.0.0.1\t-\t10.0.0.100')
actual=$(printf '10.0.0.1\t-\t10.0.0.100\n' | $GREPCIDR -D -h "10.0.0.50")
run_test "Tabs around dash" "$expected" "$actual"

expected="10.0.0.1-10.0.0.100"
actual=$(echo "10.0.0.1-10.0.0.100" | $GREPCIDR -a -D -h "10.0.0.50")
run_test "Anchor mode with input range" "$expected" "$actual"

#######################################
# -C: input range fully covered by pattern
#######################################
echo
echo "=== -C: full-cover matching of input ranges ==="

expected="10.0.0.1-10.0.0.100"
actual=$(echo "10.0.0.1-10.0.0.100" | $GREPCIDR -C -h "10.0.0.0/8")
run_test "-C: pattern covers entire input range" "$expected" "$actual"

expected=""
actual=$(echo "10.0.0.1-10.0.0.100" | $GREPCIDR -C -h "10.0.0.50-10.0.0.60")
run_test "-C: pattern only inside input range, no match" "$expected" "$actual"

expected=""
actual=$(echo "10.0.0.1-10.0.0.100" | $GREPCIDR -C -h "10.0.0.0/30")
run_test "-C: input range extends beyond pattern, no match" "$expected" "$actual"

#######################################
# Without -C/-D: behavior unchanged
#######################################
echo
echo "=== Without -C/-D: behavior unchanged ==="

expected=""
actual=$(echo "10.0.0.1-10.0.0.100" | $GREPCIDR -h "10.0.0.50")
run_test "No flags: IP inside range does not match" "$expected" "$actual"

expected="10.0.0.1-10.0.0.100"
actual=$(echo "10.0.0.1-10.0.0.100" | $GREPCIDR -h "10.0.0.100")
run_test "No flags: endpoint IP still matches as single IP" "$expected" "$actual"

expected="10.0.0.1-10.0.0.100"
actual=$(echo "10.0.0.1-10.0.0.100" | $GREPCIDR -h "10.0.0.0/8")
run_test "No flags: endpoint inside CIDR still matches" "$expected" "$actual"

#######################################
# Invalid ranges fall back to single-IP behavior
#######################################
echo
echo "=== Invalid ranges fall back to single-IP behavior ==="

expected=""
actual=$(echo "10.0.0.1-" | $GREPCIDR -D -h "10.0.0.50")
run_test "Trailing dash, no match for inside IP" "$expected" "$actual"

expected="10.0.0.1-"
actual=$(echo "10.0.0.1-" | $GREPCIDR -D -h "10.0.0.1")
run_test "Trailing dash, first IP still matches as single IP" "$expected" "$actual"

expected=""
actual=$(echo "10.0.0.1-abc" | $GREPCIDR -D -h "10.0.0.50")
run_test "Junk after dash is not a range" "$expected" "$actual"

expected=""
actual=$(echo "10.0.0.1-999.0.0.1" | $GREPCIDR -D -h "10.0.0.50")
run_test "Octet > 255 is not a range" "$expected" "$actual"

expected=""
actual=$(echo "10.0.0.1-10.0.0.1.1" | $GREPCIDR -D -h "10.0.0.50")
run_test "Five octets in end IP is not a range" "$expected" "$actual"

expected=""
actual=$(echo "10.0.1-10.0.2" | $GREPCIDR -D -h "10.0.1.0/24")
run_test "Short IPs are not a range" "$expected" "$actual"

expected=""
actual=$(printf '10.0.0.1 \n-10.0.0.2\n' | $GREPCIDR -D -h "10.0.0.15")
run_test "Range never spans a newline" "$expected" "$actual"

expected=""
actual=$(echo "10.0.0.1-10.0.0.2" | $GREPCIDR -D -h "2001:db8::/32")
run_test "IPv4 range with IPv6-only patterns, no match" "$expected" "$actual"

#######################################
# Multiple ranges / mixed addresses on one line
#######################################
echo
echo "=== Multiple ranges and mixed addresses ==="

expected="1.2.3.4-5.6.7.8 9.10.11.12-13.14.15.16"
actual=$(echo "1.2.3.4-5.6.7.8 9.10.11.12-13.14.15.16" | $GREPCIDR -D -h "9.10.11.13")
run_test "Second range on a line matches" "$expected" "$actual"

expected="10.0.0.1-10.0.0.100 10.0.0.200"
actual=$(echo "10.0.0.1-10.0.0.100 10.0.0.200" | $GREPCIDR -D -h "10.0.0.200")
run_test "IP after a non-matching range still matches" "$expected" "$actual"

expected="1"
actual=$(echo "10.0.0.1-10.0.0.100 10.0.0.1" | $GREPCIDR -D -c -h "10.0.0.50")
run_test "Matching range counts the line exactly once" "$expected" "$actual"

#######################################
# -c, -v, -o combinations
#######################################
echo
echo "=== Option combinations ==="

expected="1"
actual=$(echo "10.0.0.1-10.0.0.100" | $GREPCIDR -D -c -h "10.0.0.50")
run_test "-c counts matching range line" "$expected" "$actual"

expected="1"
actual=$(echo "9.9.9.1-9.9.9.100" | $GREPCIDR -v -D -c -h "10.0.0.0/8")
run_test "-v -c counts non-matching range line" "$expected" "$actual"

expected=""
actual=$(echo "no ips here" | $GREPCIDR -v -D -h "10.0.0.0/8")
run_test "-v: line without IPs not printed" "$expected" "$actual"

expected="10.0.0.50-10.0.0.60"
actual=$(echo "10.0.0.1-10.0.0.100" | $GREPCIDR -o -D -h "10.0.0.50-10.0.0.60")
run_test "-o -D prints overlapping pattern" "$expected" "$actual"

expected="10.0.0.0/8"
actual=$(echo "10.0.0.1-10.0.0.100" | $GREPCIDR -o -D -h "10.0.0.0/8")
run_test "-o -D prints pattern once for range line" "$expected" "$actual"

expected="1"
actual=$(echo "10.0.0.50 10.0.0.60" | $GREPCIDR -o -c -h "10.0.0.0/8")
run_test "-o -c counts a line with two matching IPs once" "$expected" "$actual"

expected="10.0.0.0/8"
actual=$(echo "10.0.0.50 10.0.0.60" | $GREPCIDR -o -h "10.0.0.0/8")
run_test "-o prints pattern once for line with two matching IPs" "$expected" "$actual"

#######################################
# Pattern files and multiple input files
#######################################
echo
echo "=== Pattern files and multiple input files ==="

cat > "$TMPDIR/patterns.txt" <<EOF
# range patterns
192.168.0.1-192.168.0.50

10.0.0.0/8
EOF

expected="192.168.0.25"
actual=$(echo "192.168.0.25" | $GREPCIDR -D -f "$TMPDIR/patterns.txt")
run_test "Range pattern from pattern file" "$expected" "$actual"

expected="10.5.5.5"
actual=$(echo "10.5.5.5" | $GREPCIDR -D -f "$TMPDIR/patterns.txt")
run_test "CIDR pattern from same pattern file" "$expected" "$actual"

echo "192.168.0.25" > "$TMPDIR/file1.txt"
echo "10.0.0.1-10.0.0.100" > "$TMPDIR/file2.txt"

expected="file2.txt:10.0.0.1-10.0.0.100"
actual=$($GREPCIDR -D "10.0.0.50" "$TMPDIR/file1.txt" "$TMPDIR/file2.txt" | sed "s|$TMPDIR/||")
run_test "Multiple input files, range line matched with filename" "$expected" "$actual"

#######################################
# CIDR input behavior unchanged (regression)
#######################################
echo
echo "=== CIDR input behavior unchanged (regression) ==="

expected="10.0.0.1/8"
actual=$(echo "10.0.0.1/8" | $GREPCIDR -D -h "10.0.0.50")
run_test "-D: CIDR input overlapping pattern still matches" "$expected" "$actual"

expected="10.0.0.0/16"
actual=$(echo "10.0.0.0/16" | $GREPCIDR -C -h "10.0.0.0/8")
run_test "-C: CIDR input covered by pattern still matches" "$expected" "$actual"

expected=""
actual=$(echo "10.0.0.0/8" | $GREPCIDR -C -h "10.1.0.0/16")
run_test "-C: CIDR input only partially covered, no match" "$expected" "$actual"

expected="10.0.0.0/8"
actual=$(echo "10.0.0.0/8" | $GREPCIDR -D -h "10.1.0.0/16")
run_test "-D: CIDR input partially covered, overlap matches" "$expected" "$actual"

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
