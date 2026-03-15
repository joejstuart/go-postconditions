# =========================
# Post-Conditions Makefile (Go)
# Tools are pinned in tools/go.mod (no @versions here)
# =========================

MAKEFLAGS += --no-print-directory
SHELL := bash

GOFLAGS ?=
TEST_PKGS ?= ./...
COVER_OUT ?= coverage.out
COVER_FLOOR ?= 80
GOCYCLO_MAX ?= 12         # cyclomatic complexity budget for gocyclo
COGNIT_MAX  ?= 20         # cognitive complexity budget for gocognit

# Run tools through the tools module (do NOT cd tools/)
GO_RUN_TOOLS = go run -modfile tools/go.mod
GOLANGCI := $(GO_RUN_TOOLS) github.com/golangci/golangci-lint/cmd/golangci-lint

# Source lists for tools that need explicit files (not ./...)
GO_SOURCES := $(shell git ls-files '*.go' ':!:**/*.pb.go')
# If your repo includes generated dirs, exclude them above (add more :!: patterns as needed)

# In CI, disallow go.mod/go.sum edits during steps
ifdef CI
GOFLAGS += -mod=readonly
endif

# Colors for output
GREEN  := \033[32m
YELLOW := \033[33m
CYAN   := \033[36m
RESET  := \033[0m

.PHONY: help
help: ## Show available targets
	@awk 'BEGIN{FS=":.*##";print "\nTargets:"} /^[a-zA-Z0-9_.-]+:.*?##/ {printf "  $(CYAN)%-22s$(RESET) %s\n", $$1, $$2}' $(MAKEFILE_LIST)

# --- Formatting (non-mutating) ---
.PHONY: fmt
fmt: ## Verify gofmt -s (non-mutating)
	@changed="$$(gofmt -s -l .)"; \
	if [ -n "$$changed" ]; then \
	  echo "$(YELLOW)Files need formatting:$(RESET)"; echo "$$changed" | sed 's/^/  /'; \
	  echo "Run: make fmt-fix"; exit 1; \
	fi
	@echo "$(GREEN)✓ fmt$(RESET)"

.PHONY: fmt-fix
fmt-fix: ## Apply gofmt -s (local use)
	@gofmt -s -w .
	@echo "$(GREEN)✓ fmt-fix$(RESET)"

# --- Static analysis and security (single-tool runners) ---
.PHONY: vet
vet: ## go vet
	@go vet $(GOFLAGS) $(TEST_PKGS)
	@echo "$(GREEN)✓ vet$(RESET)"

.PHONY: staticcheck
staticcheck: ## staticcheck (includes gosimple)
	@$(GO_RUN_TOOLS) honnef.co/go/tools/cmd/staticcheck $(TEST_PKGS)
	@echo "$(GREEN)✓ staticcheck$(RESET)"

.PHONY: revive
revive: ## revive (style linter)
	@$(GO_RUN_TOOLS) github.com/mgechev/revive $(TEST_PKGS)
	@echo "$(GREEN)✓ revive$(RESET)"

.PHONY: errcheck
errcheck: ## errcheck (error handling)
	@$(GO_RUN_TOOLS) github.com/kisielk/errcheck $(TEST_PKGS)
	@echo "$(GREEN)✓ errcheck$(RESET)"

.PHONY: vuln
vuln: ## govulncheck (module + packages)
	@$(GO_RUN_TOOLS) golang.org/x/vuln/cmd/govulncheck $(TEST_PKGS)
	@echo "$(GREEN)✓ vuln$(RESET)"

# --- Extra "Go patterns" linters (standalone CLIs) ---------------------------
# NOTE: These are optional deeper checks. Many overlap with golangci-lint linters used in sanity.
# We keep them separate so day-to-day iteration stays fast; run them in pre-PR or locally as needed.

.PHONY: gocyclo
gocyclo: ## gocyclo (cyclomatic complexity) - fails if > GOCYCLO_MAX
	@$(GO_RUN_TOOLS) github.com/fzipp/gocyclo/cmd/gocyclo -over $(GOCYCLO_MAX) $(GO_SOURCES)
	@echo "$(GREEN)✓ gocyclo (max: $(GOCYCLO_MAX))$(RESET)"

.PHONY: nestif
nestif: ## nestif (nested if statements)
	@$(GO_RUN_TOOLS) github.com/nakabonne/nestif/cmd/nestif .
	@echo "$(GREEN)✓ nestif$(RESET)"

.PHONY: dupl
dupl: ## dupl (duplicate code detection)
	@$(GO_RUN_TOOLS) github.com/mibk/dupl .
	@echo "$(GREEN)✓ dupl$(RESET)"

.PHONY: goconst
goconst: ## goconst (repeated string/number literals)
	@$(GOLANGCI) run --disable-all --enable=goconst ./...
	@echo "$(GREEN)✓ goconst$(RESET)"

.PHONY: misspell
misspell: ## misspell (spelling checker; errors only)
	@$(GO_RUN_TOOLS) github.com/client9/misspell/cmd/misspell -error -locale US $(GO_SOURCES)
	@echo "$(GREEN)✓ misspell$(RESET)"

.PHONY: unparam
unparam: ## unparam (unused parameters)
	@$(GO_RUN_TOOLS) mvdan.cc/unparam $(TEST_PKGS)
	@echo "$(GREEN)✓ unparam$(RESET)"

.PHONY: ineffassign
ineffassign: ## ineffassign (ineffective assignments)
	@$(GO_RUN_TOOLS) github.com/gordonklaus/ineffassign .
	@echo "$(GREEN)✓ ineffassign$(RESET)"

.PHONY: gosec
gosec: ## gosec (security issues)
	@$(GO_RUN_TOOLS) github.com/securego/gosec/v2/cmd/gosec -quiet ./...
	@echo "$(GREEN)✓ gosec$(RESET)"

.PHONY: gocritic
gocritic: ## gocritic (style and performance issues)
	@$(GO_RUN_TOOLS) github.com/go-critic/go-critic/cmd/gocritic check ./...
	@echo "$(GREEN)✓ gocritic$(RESET)"

.PHONY: gocognit
gocognit: ## gocognit (cognitive complexity) - fails if > COGNIT_MAX
	@$(GO_RUN_TOOLS) github.com/uudashr/gocognit/cmd/gocognit -over $(COGNIT_MAX) $(GO_SOURCES)
	@echo "$(GREEN)✓ gocognit (max: $(COGNIT_MAX))$(RESET)"

.PHONY: funlen
funlen: ## funlen (function length)
	@$(GO_RUN_TOOLS) github.com/ultraware/funlen/cmd/funlen ./...
	@echo "$(GREEN)✓ funlen$(RESET)"

.PHONY: gofumpt
gofumpt: ## gofumpt (stricter gofmt; non-mutating)
	@changed="$$($(GO_RUN_TOOLS) mvdan.cc/gofumpt -l $(GO_SOURCES))"; \
	if [ -n "$$changed" ]; then \
	  echo "$(YELLOW)Files need gofumpt:$(RESET)"; echo "$$changed" | sed 's/^/  /'; \
	  exit 1; \
	fi
	@echo "$(GREEN)✓ gofumpt$(RESET)"

# --- Lint (keeps using .golangci.yml exactly as-is) --------------------------
.PHONY: lint
lint: ## Full golangci-lint run (uses .golangci.yml)
	@$(GOLANGCI) run --sort-results $(if $(CI),--timeout=10m)
	@echo "$(GREEN)✓ lint$(RESET)"

# --------- Sanity: checks & reports (isolated from .golangci.yml) ------------

# Public knobs:
#   FILES=""                     # optional: files/dirs to scope the run
#   SANITY_JSON=.sanity.json     # where JSON lands for report-sanity
#   SANITY_BUILD_TAGS=...        # build tags for sanity runs
#   SANITY_NO_CONFIG=0           # 0 = use .golangci.yml (default), 1 = ignore it
SANITY_JSON ?= .sanity.json
SANITY_BUILD_TAGS ?= acceptance,generative,integration,unit
SANITY_NO_CONFIG ?= 0

SANITY_LINTERS = -E dupl -E gocyclo -E goconst -E unparam -E ineffassign -E nestif
SANITY_BASE    = --max-issues-per-linter=0 --max-same-issues=0 --sort-results --timeout=5m --build-tags=$(SANITY_BUILD_TAGS)
SANITY_CFG_FLAGS =
ifeq ($(SANITY_NO_CONFIG),1)
  SANITY_CFG_FLAGS = --no-config --disable-all
endif

# 1) CHECK: human-friendly output, fails on issues.
.PHONY: check-sanity
check-sanity: ## Run sanity checks (FILES=... optional). Uses .golangci.yml by default.
	@$(GOLANGCI) run $(SANITY_CFG_FLAGS) $(SANITY_LINTERS) $(SANITY_BASE) --issues-exit-code=1 \
	  --out-format=colored-line-number $(if $(FILES),$(FILES),)
	@echo "$(GREEN)✓ check-sanity passed (gocyclo budget: $(GOCYCLO_MAX))$(RESET)"

# 2) REPORT: summarized output, never fails; uses JSON internally.
.PHONY: report-sanity
report-sanity: ## Summarize sanity issues (FILES=... optional)
	@$(GOLANGCI) run $(SANITY_CFG_FLAGS) $(SANITY_LINTERS) $(SANITY_BASE) --issues-exit-code=0 \
	  --out-format json $(if $(FILES),$(FILES),) > $(SANITY_JSON)
	@command -v jq >/dev/null || { echo "jq is required for report-sanity"; exit 1; }
	@echo "== Issues by linter =="; \
	jq -r '.Issues | group_by(.FromLinter) | map({linter: .[0].FromLinter, count: length}) | sort_by(-.count) | (["linter","count"], (.[] | [ .linter, (.count|tostring) ])) | @tsv' $(SANITY_JSON) | column -t
	@echo; echo "== Top files by issue count (top 10) =="; \
	jq -r '.Issues | group_by(.Pos.Filename) | map({file: .[0].Pos.Filename, count: length}) | sort_by(-.count)[0:10] | (["file","count"], (.[] | [ .file, (.count|tostring) ])) | @tsv' $(SANITY_JSON) | column -t
	@echo; echo "== Worst cyclomatic complexity (top 10) =="; \
	jq -r '.Issues | map(select(.FromLinter=="gocyclo")) | map({file: .Pos.Filename, line: .Pos.Line, text: .Text, n: ( .Text | capture("(?<n>[0-9]+)"; "m")? | .n // "0") | tonumber}) | sort_by(-.n)[0:10] | (["complexity","file:line","message"], (.[] | [ ( .n|tostring ), ( .file + ":" + (.line|tostring) ), .text ])) | @tsv' $(SANITY_JSON) | column -t
	@echo; echo "== Duplicate code (dupl) hot-spots (top 10) =="; \
	jq -r '.Issues | map(select(.FromLinter=="dupl")) | group_by(.Pos.Filename) | map({file: .[0].Pos.Filename, count: length}) | sort_by(-.count)[0:10] | (["file","dupl_issues"], (.[] | [ .file, (.count|tostring) ])) | @tsv' $(SANITY_JSON) | column -t

# Compatibility aliases (old names keep working)
.PHONY: sanity sanity-file sanity-json sanity-file-json sanity-summary sanity-file-summary
sanity: check-sanity
sanity-file: check-sanity
sanity-json: report-sanity
sanity-file-json: report-sanity
sanity-summary: report-sanity
sanity-file-summary: report-sanity

# --- Tests & Coverage ---
.PHONY: test
test: ## Run tests with race + coverage
	@go test $(GOFLAGS) -race -covermode=atomic -coverprofile=$(COVER_OUT) $(TEST_PKGS)
	@echo "$(GREEN)✓ test$(RESET)"

.PHONY: cover-merge
cover-merge: ## Merge coverage-*.out -> $(COVER_OUT)
	@set -euo pipefail; \
	files=($$(ls -1 coverage-*.out 2>/dev/null || true)); \
	if [ $${#files[@]} -eq 0 ]; then \
	  echo "No coverage-*.out files found; keeping $(COVER_OUT)"; \
	else \
	  echo "Merging: $${files[*]}"; \
	  $(GO_RUN_TOOLS) github.com/wadey/gocovmerge $${files[*]} > $(COVER_OUT); \
	fi

.PHONY: cover-check
cover-check: ## Enforce total coverage floor ($(COVER_FLOOR)%)
	@set -euo pipefail; \
	test -f "$(COVER_OUT)" || { echo "$(YELLOW)Missing $(COVER_OUT) — run 'make test' first$(RESET)"; exit 1; }; \
	pct=$$(go tool cover -func=$(COVER_OUT) | awk '/^total:/ {gsub("%","",$$3); print $$3}'); \
	if awk -v p="$$pct" -v f="$(COVER_FLOOR)" 'BEGIN{exit (p+0 >= f+0)?0:1}'; then \
	  echo "$(GREEN)✓ cover-check: $$pct% (floor: $(COVER_FLOOR)%)$(RESET)"; \
	else \
	  echo "$(YELLOW)✗ cover-check: $$pct% < $(COVER_FLOOR)% floor$(RESET)"; exit 1; \
	fi

# --- find-func-refs (repo-wide) ---
FFR = $(GO_RUN_TOOLS) github.com/joejstuart/find-func-refs

.PHONY: ffr
ffr: ## Repo-wide unused function scan (via find-func-refs -all)
	@echo "Scanning for unused functions..."
	@$(FFR) -all -root . -snippet
	@echo "$(GREEN)✓ ffr$(RESET)"

# --- Aggregate "Go patterns" suite -------------------------------------------
.PHONY: go-patterns-lint
go-patterns-lint: ## Extra Go pattern checks (run locally / pre-PR; slower than sanity)
go-patterns-lint: revive gocyclo nestif dupl goconst misspell unparam ineffassign gosec gocritic gocognit funlen gofumpt
	@echo "$(GREEN)✓ go-patterns-lint (all checks passed)$(RESET)"

# --- Stage bundles -----------------------------------------------------------
.PHONY: quick
quick: fmt check-sanity ## Small/local changes: fast guard
	@echo "$(GREEN)✓ quick (all checks passed)$(RESET)"

.PHONY: refactor
refactor: fmt check-sanity ffr go-patterns-lint ## Structural changes: add unused scan + Go patterns
	@echo "$(GREEN)✓ refactor (all checks passed)$(RESET)"

.PHONY: behavior
behavior: fmt check-sanity analysis test cover-check ## Behavior change: full quality + tests + coverage
	@echo "$(GREEN)✓ behavior (all checks passed)$(RESET)"

.PHONY: prepr
prepr: analysis test cover-check go-patterns-lint ## Pre-PR stabilization (adds deeper Go patterns)
	@echo "$(GREEN)✓ prepr (all checks passed)$(RESET)"

# --- CI / default ------------------------------------------------------------
.PHONY: analysis
analysis: fmt vet staticcheck revive errcheck vuln check-sanity ## Non-mutating quality gates
	@echo "$(GREEN)✓ analysis (all checks passed)$(RESET)"

.PHONY: ci
ci: test analysis cover-check ## Full CI suite (non-mutating)
	@echo "$(GREEN)✓ ci (all checks passed)$(RESET)"

# --- Optional perf smoke (won't fail CI) ---
.PHONY: bench-smoke
bench-smoke: ## Run quick benchmarks (informational)
	@go test $(GOFLAGS) -run=^$$ -bench=. -benchmem ./... || true
	@echo "$(CYAN)bench-smoke complete$(RESET)"

.DEFAULT_GOAL := ci
