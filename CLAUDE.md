# Go Postconditions

This repository provides Makefile targets and Go tools for validating code changes and ensuring code quality.

## Validation Rules

See [docs/validation-rules.md](docs/validation-rules.md) for the complete validation workflow.

## Quick Reference

| Change Type | Command |
|-------------|---------|
| Single file | `make check-sanity FILES="./path/to/file.go"` |
| Multi-file | `make check-sanity` |
| Refactor | `make refactor && make test` |
| Behavior change | `make behavior` |
| Pre-commit | `make prepr` |

## Key Targets

- `make help` - Show all available targets
- `make check-sanity` - Run sanity checks (fast)
- `make report-sanity` - Generate detailed report with jq
- `make ci` - Full CI suite (tests + analysis + coverage)

## Tool Dependencies

Tools are pinned in `tools/go.mod` and run via `go run -modfile tools/go.mod`. No global installation required.
