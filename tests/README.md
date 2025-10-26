# grepcidr Test Suite

Automated tests for grepcidr functionality, organized by option.

## Quick Start

```bash
make test
```

## Current Test Suites

### `-o` Option Tests

Print matching CIDR pattern instead of input line.

- **Script:** `test_o_option.sh`
- **Tests:** 33 (all passing)
- **Docs:** [TEST_O_OPTION.md](TEST_O_OPTION.md), [AWS_TEST_VALIDATION.md](AWS_TEST_VALIDATION.md), [TESTING_SUMMARY.txt](TESTING_SUMMARY.txt)

Run: `./tests/test_o_option.sh`

## Adding New Tests

When adding tests for a new option:

1. Create `test_<option>.sh` in this directory
2. Make it executable: `chmod +x test_<option>.sh`
3. Follow the pattern in `test_o_option.sh`:
   - Use colors for output (GREEN/RED/NC)
   - Find grepcidr binary (check `./` and `../`)
   - Use temporary directories and clean up
   - Print clear test names and expected vs actual on failure
4. Create supporting documentation as needed
5. Update this README with a new section

The `make test` target will automatically discover and run your new test script.

## Test File Naming

- `test_<option>.sh` - Main test script (auto-discovered by make test)
- `TEST_<OPTION>_*.md` - Detailed documentation
- `test_*.txt` - Test data files (git-ignored)
