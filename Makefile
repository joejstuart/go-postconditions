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

# Colors for output (use printf, not echo)
GREEN  := \033[32m
YELLOW := \033[33m
CYAN   := \033[36m
RESET  := \033[0m
OK     = @printf '$(GREEN)✓ %s$(RESET)\n'
WARN   = @printf '$(YELLOW)%s$(RESET)\n'
INFO   = @printf '$(CYAN)%s$(RESET)\n'

.PHONY: help
help: ## Show available targets
	@awk 'BEGIN{FS=":.*##";printf "\nTargets:\n"} /^[a-zA-Z0-9_.-]+:.*?##/ {printf "  \033[36m%-22s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

# --- Formatting (non-mutating) ---
.PHONY: fmt
fmt: ## Verify gofmt -s (non-mutating)
	@changed="$$(gofmt -s -l .)"; \
	if [ -n "$$changed" ]; then \
	  printf '$(YELLOW)Files need formatting:$(RESET)\n'; echo "$$changed" | sed 's/^/  /'; \
	  echo "Run: make fmt-fix"; exit 1; \
	fi
	$(OK) 'fmt'

.PHONY: fmt-fix
fmt-fix: ## Apply gofmt -s (local use)
	@gofmt -s -w .
	$(OK) 'fmt-fix'

# --- Static analysis and security (single-tool runners) ---
.PHONY: vet
vet: ## go vet
	@go vet $(GOFLAGS) $(TEST_PKGS)
	$(OK) 'vet'

.PHONY: staticcheck
staticcheck: ## staticcheck (includes gosimple)
	@$(GO_RUN_TOOLS) honnef.co/go/tools/cmd/staticcheck $(TEST_PKGS)
	$(OK) 'staticcheck'

.PHONY: revive
revive: ## revive (style linter)
	@$(GO_RUN_TOOLS) github.com/mgechev/revive $(TEST_PKGS)
	$(OK) 'revive'

.PHONY: errcheck
errcheck: ## errcheck (error handling)
	@$(GO_RUN_TOOLS) github.com/kisielk/errcheck $(TEST_PKGS)
	$(OK) 'errcheck'

.PHONY: vuln
vuln: ## govulncheck (module + packages)
	@$(GO_RUN_TOOLS) golang.org/x/vuln/cmd/govulncheck $(TEST_PKGS)
	$(OK) 'vuln'

# --- Extra "Go patterns" linters (standalone CLIs) ---------------------------
# NOTE: These are optional deeper checks. Many overlap with golangci-lint linters used in sanity.
# We keep them separate so day-to-day iteration stays fast; run them in pre-PR or locally as needed.

.PHONY: gocyclo
gocyclo: ## gocyclo (cyclomatic complexity) - fails if > GOCYCLO_MAX
	@$(GO_RUN_TOOLS) github.com/fzipp/gocyclo/cmd/gocyclo -over $(GOCYCLO_MAX) $(GO_SOURCES)
	$(OK) 'gocyclo (max: $(GOCYCLO_MAX))'

.PHONY: nestif
nestif: ## nestif (nested if statements)
	@$(GO_RUN_TOOLS) github.com/nakabonne/nestif/cmd/nestif .
	$(OK) 'nestif'

.PHONY: dupl
dupl: ## dupl (duplicate code detection)
	@$(GO_RUN_TOOLS) github.com/mibk/dupl .
	$(OK) 'dupl'

.PHONY: goconst
goconst: ## goconst (repeated string/number literals)
	@$(GOLANGCI) run --disable-all --enable=goconst ./...
	$(OK) 'goconst'

.PHONY: misspell
misspell: ## misspell (spelling checker; errors only)
	@$(GO_RUN_TOOLS) github.com/client9/misspell/cmd/misspell -error -locale US $(GO_SOURCES)
	$(OK) 'misspell'

.PHONY: unparam
unparam: ## unparam (unused parameters)
	@$(GO_RUN_TOOLS) mvdan.cc/unparam $(TEST_PKGS)
	$(OK) 'unparam'

.PHONY: ineffassign
ineffassign: ## ineffassign (ineffective assignments)
	@$(GO_RUN_TOOLS) github.com/gordonklaus/ineffassign .
	$(OK) 'ineffassign'

.PHONY: gosec
gosec: ## gosec (security issues)
	@$(GO_RUN_TOOLS) github.com/securego/gosec/v2/cmd/gosec -quiet ./...
	$(OK) 'gosec'

.PHONY: gocritic
gocritic: ## gocritic (style and performance issues)
	@$(GO_RUN_TOOLS) github.com/go-critic/go-critic/cmd/gocritic check ./...
	$(OK) 'gocritic'

.PHONY: gocognit
gocognit: ## gocognit (cognitive complexity) - fails if > COGNIT_MAX
	@$(GO_RUN_TOOLS) github.com/uudashr/gocognit/cmd/gocognit -over $(COGNIT_MAX) $(GO_SOURCES)
	$(OK) 'gocognit (max: $(COGNIT_MAX))'

.PHONY: funlen
funlen: ## funlen (function length)
	@$(GO_RUN_TOOLS) github.com/ultraware/funlen/cmd/funlen ./...
	$(OK) 'funlen'

.PHONY: gofumpt
gofumpt: ## gofumpt (stricter gofmt; non-mutating)
	@changed="$$($(GO_RUN_TOOLS) mvdan.cc/gofumpt -l $(GO_SOURCES))"; \
	if [ -n "$$changed" ]; then \
	  printf '$(YELLOW)Files need gofumpt:$(RESET)\n'; echo "$$changed" | sed 's/^/  /'; \
	  exit 1; \
	fi
	$(OK) 'gofumpt'

# --- Lint (keeps using .golangci.yml exactly as-is) --------------------------
.PHONY: lint
lint: ## Full golangci-lint run (uses .golangci.yml)
	@$(GOLANGCI) run --sort-results $(if $(CI),--timeout=10m)
	$(OK) 'lint'

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
	$(OK) 'check-sanity (gocyclo budget: $(GOCYCLO_MAX))'

# 2) REPORT: summarized output, never fails; uses JSON internally.
.PHONY: report-sanity
report-sanity: ## Summarize sanity issues (FILES=... optional)
	@$(GOLANGCI) run $(SANITY_CFG_FLAGS) $(SANITY_LINTERS) $(SANITY_BASE) --issues-exit-code=0 \
	  --out-format json $(if $(FILES),$(FILES),) > $(SANITY_JSON)
	@command -v jq >/dev/null || { printf 'jq is required for report-sanity\n'; exit 1; }
	@count=$$(jq '.Issues | length' $(SANITY_JSON)); \
	if [ "$$count" -eq 0 ]; then \
	  printf '$(GREEN)✓ No issues found$(RESET)\n'; \
	else \
	  printf '$(YELLOW)Found %d issues:$(RESET)\n\n' "$$count"; \
	  printf '$(CYAN)Issues by linter:$(RESET)\n'; \
	  jq -r '.Issues | group_by(.FromLinter) | map({linter: .[0].FromLinter, count: length}) | sort_by(-.count) | .[] | "  \(.linter): \(.count)"' $(SANITY_JSON); \
	  printf '\n$(CYAN)Top files (max 10):$(RESET)\n'; \
	  jq -r '.Issues | group_by(.Pos.Filename) | map({file: .[0].Pos.Filename, count: length}) | sort_by(-.count)[0:10] | .[] | "  \(.file): \(.count)"' $(SANITY_JSON); \
	  cyclo=$$(jq '.Issues | map(select(.FromLinter=="gocyclo")) | length' $(SANITY_JSON)); \
	  if [ "$$cyclo" -gt 0 ]; then \
	    printf '\n$(CYAN)Cyclomatic complexity (max 10):$(RESET)\n'; \
	    jq -r '.Issues | map(select(.FromLinter=="gocyclo")) | sort_by(.Pos.Filename, .Pos.Line)[0:10] | .[] | "  \(.Pos.Filename):\(.Pos.Line) - \(.Text)"' $(SANITY_JSON); \
	  fi; \
	  dupl=$$(jq '.Issues | map(select(.FromLinter=="dupl")) | length' $(SANITY_JSON)); \
	  if [ "$$dupl" -gt 0 ]; then \
	    printf '\n$(CYAN)Duplicate code (max 10):$(RESET)\n'; \
	    jq -r '.Issues | map(select(.FromLinter=="dupl")) | group_by(.Pos.Filename) | map({file: .[0].Pos.Filename, count: length}) | sort_by(-.count)[0:10] | .[] | "  \(.file): \(.count) instances"' $(SANITY_JSON); \
	  fi; \
	fi

# Compatibility aliases (old names keep working)
.PHONY: sanity sanity-file sanity-json sanity-file-json sanity-summary sanity-file-summary sanity-report
sanity: check-sanity
sanity-file: check-sanity
sanity-json: report-sanity
sanity-file-json: report-sanity
sanity-summary: report-sanity
sanity-file-summary: report-sanity
sanity-report: report-sanity

# --- Tests & Coverage ---
.PHONY: test
test: ## Run tests with race + coverage
	@go test $(GOFLAGS) -race -covermode=atomic -coverprofile=$(COVER_OUT) $(TEST_PKGS)
	$(OK) 'test'

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
	test -f "$(COVER_OUT)" || { printf '$(YELLOW)Missing $(COVER_OUT) — run make test first$(RESET)\n'; exit 1; }; \
	pct=$$(go tool cover -func=$(COVER_OUT) | awk '/^total:/ {gsub("%","",$$3); print $$3}'); \
	if awk -v p="$$pct" -v f="$(COVER_FLOOR)" 'BEGIN{exit (p+0 >= f+0)?0:1}'; then \
	  printf '$(GREEN)✓ cover-check: %s%% (floor: $(COVER_FLOOR)%%)$(RESET)\n' "$$pct"; \
	else \
	  printf '$(YELLOW)✗ cover-check: %s%% < $(COVER_FLOOR)%% floor$(RESET)\n' "$$pct"; exit 1; \
	fi

# --- find-func-refs (repo-wide) ---
FFR = $(GO_RUN_TOOLS) github.com/joejstuart/find-func-refs

.PHONY: ffr
ffr: ## Repo-wide unused function scan (via find-func-refs -all)
	@printf 'Scanning for unused functions...\n'
	@$(FFR) -all -root . -snippet
	$(OK) 'ffr'

# --- Aggregate "Go patterns" suite -------------------------------------------
.PHONY: go-patterns-lint
go-patterns-lint: ## Extra Go pattern checks (run locally / pre-PR; slower than sanity)
go-patterns-lint: revive gocyclo nestif dupl goconst misspell unparam ineffassign gosec gocritic gocognit funlen gofumpt
	$(OK) 'go-patterns-lint (all passed)'

# --- Stage bundles -----------------------------------------------------------
.PHONY: quick
quick: fmt check-sanity ## Small/local changes: fast guard
	$(OK) 'quick (all passed)'

.PHONY: refactor
refactor: fmt check-sanity ffr go-patterns-lint ## Structural changes: add unused scan + Go patterns
	$(OK) 'refactor (all passed)'

.PHONY: behavior
behavior: fmt check-sanity analysis test cover-check ## Behavior change: full quality + tests + coverage
	$(OK) 'behavior (all passed)'

.PHONY: prepr
prepr: analysis test cover-check go-patterns-lint ## Pre-PR stabilization (adds deeper Go patterns)
	$(OK) 'prepr (all passed)'

# --- CI / default ------------------------------------------------------------
.PHONY: analysis
analysis: fmt vet staticcheck revive errcheck vuln check-sanity ## Non-mutating quality gates
	$(OK) 'analysis (all passed)'

.PHONY: ci
ci: test analysis cover-check ## Full CI suite (non-mutating)
	$(OK) 'ci (all passed)'

# --- Optional perf smoke (won't fail CI) ---
.PHONY: bench-smoke
bench-smoke: ## Run quick benchmarks (informational)
	@go test $(GOFLAGS) -run=^$$ -bench=. -benchmem ./... || true
	$(INFO) 'bench-smoke complete'

.DEFAULT_GOAL := ci
