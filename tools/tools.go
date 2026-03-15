//go:build tools
// +build tools

package main

import (
	_ "github.com/client9/misspell/cmd/misspell"
	_ "github.com/fzipp/gocyclo/cmd/gocyclo"
	_ "github.com/go-critic/go-critic/cmd/gocritic"
	_ "github.com/golangci/golangci-lint/cmd/golangci-lint"
	_ "github.com/gordonklaus/ineffassign"
	_ "github.com/joejstuart/find-func-refs"
	_ "github.com/kisielk/errcheck"
	_ "github.com/mgechev/revive"
	_ "github.com/mibk/dupl"
	_ "github.com/nakabonne/nestif/cmd/nestif"
	_ "github.com/securego/gosec/v2/cmd/gosec"
	_ "github.com/ultraware/funlen/cmd/funlen"
	_ "github.com/uudashr/gocognit/cmd/gocognit"
	_ "github.com/wadey/gocovmerge"
	_ "golang.org/x/vuln/cmd/govulncheck"
	_ "honnef.co/go/tools/cmd/staticcheck"
	_ "mvdan.cc/gofumpt"
	_ "mvdan.cc/unparam"
)
