# Testing the -o Option

This document describes how to test the `-o` (print matching pattern) option implementation.

## Quick Start

Run the comprehensive test suite:

```bash
./test_o_option.sh
```

This will run 28 automated tests covering all aspects of the `-o` option functionality.

## What the -o Option Does

The `-o` option changes the output behavior of grepcidr:
- **Without `-o`**: Prints the input lines that match the CIDR patterns
- **With `-o`**: Prints the matching CIDR pattern instead of the input line

### Narrowest Match Selection

When an IP address matches multiple overlapping CIDR ranges, the `-o` option automatically selects the **narrowest** (most specific) matching pattern. This is the key feature that makes `-o` useful for IP address classification.

**Example:**
```bash
$ cat patterns.txt
192.168.0.0/16
192.168.1.0/24
192.168.1.128/25

$ echo "192.168.1.200" | ./grepcidr -o -f patterns.txt
192.168.1.128/25
```

In this example, 192.168.1.200 matches all three patterns, but `/25` is the narrowest, so it's printed.

## Test Coverage

The test suite covers:

### Basic Functionality (Tests 1-3)
- Single IPv4 pattern matching
- Multiple patterns in a file
- Non-matching IPs return empty output

### Narrowest Match Selection (Tests 4-7)
- IPv4 narrowest match from overlapping ranges
- IPs in different ranges select appropriate patterns
- Proper fallback to less specific ranges

### Multiple IP Processing (Test 8)
- Batch processing from file input
- Consistent narrowest match for each IP

### IPv6 Support (Tests 9-12)
- IPv6 pattern matching
- IPv6 narrowest match selection
- Non-matching IPv6 addresses

### Mixed IPv4/IPv6 (Test 13)
- Pattern files containing both IPv4 and IPv6
- Correct classification of each address type

### Input Methods (Test 14)
- Reading from stdin
- Reading from files

### Backward Compatibility (Tests 15-16)
- Normal mode (without `-o`) still works correctly
- No regression in existing functionality

### Edge Cases (Tests 17-20)
- Exact IP matches (/32, /128)
- Single IP patterns
- Comments and empty lines in pattern files

### Complex Scenarios (Tests 21-23)
- Many overlapping ranges (6+ levels)
- Pattern ordering preferences for equal-sized ranges
- Later patterns preferred for same-size matches

### Feature Integration (Tests 24-25)
- Pattern output includes newlines properly
- Count mode (`-c`) works with `-o`

### Real-World Use Cases (Tests 26-28)
- AWS IP range classification
- Large pattern sets (100+ patterns)
- IPv4-mapped IPv6 addresses

## Manual Testing Examples

### Example 1: AWS IP Range Classification
```bash
# Create a pattern file with AWS IP ranges
cat > aws_ranges.txt <<EOF
52.94.0.0/16
52.95.0.0/16
54.239.0.0/16
EOF

# Classify an IP
echo "52.94.76.35" | ./grepcidr -o -f aws_ranges.txt
# Output: 52.94.0.0/16
```

### Example 2: Network Hierarchy
```bash
# Create overlapping patterns representing network hierarchy
cat > network.txt <<EOF
10.0.0.0/8          # Corporate network
10.10.0.0/16        # Branch office
10.10.10.0/24       # Development subnet
10.10.10.128/25     # Production servers
EOF

# Classify IPs in different parts of the hierarchy
echo "10.50.1.1" | ./grepcidr -o -f network.txt
# Output: 10.0.0.0/8

echo "10.10.5.1" | ./grepcidr -o -f network.txt
# Output: 10.10.0.0/16

echo "10.10.10.50" | ./grepcidr -o -f network.txt
# Output: 10.10.10.0/24

echo "10.10.10.200" | ./grepcidr -o -f network.txt
# Output: 10.10.10.128/25
```

### Example 3: Batch Processing
```bash
# Process multiple IPs at once
cat ips.txt | ./grepcidr -o -f patterns.txt > classifications.txt
```

## Implementation Details

The `-o` option implementation includes:

1. **Data Structure Changes**:
   - Added `original_line` field to `netspec` and `netspec6` structs
   - Stores the original pattern string from the input file

2. **Narrowest Match Algorithm**:
   - When `-o` is enabled, uses linear search instead of binary search
   - Compares range sizes to find the narrowest match
   - Handles equal-sized ranges by preferring later patterns

3. **State Machine Updates**:
   - Added `S_SCNLPO` state for printing original patterns
   - Modified state transitions to conditionally use `S_SCNLPO`
   - Added label dispatch to handle grepcidr3's optimized scanning

4. **Function Signatures**:
   - Updated `netmatch()` and `netmatch6()` to accept `const char **original_line`
   - All call sites updated to pass the parameter

5. **Range Merging**:
   - Disabled when `-o` is enabled to preserve all patterns
   - Ensures narrowest match selection works correctly

## Known Limitations

- The `-v` (invert match) option combined with `-o` may have undefined behavior
- IPv4-mapped IPv6 addresses may not be fully supported (test documents current behavior)

## Troubleshooting

If tests fail:

1. Make sure grepcidr is compiled: `make clean && make`
2. Run with debug output: `bash -x ./test_o_option.sh`
3. Check individual tests manually
