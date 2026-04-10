SHELL := /bin/bash
.SILENT:
.ONESHELL:
.DEFAULT_GOAL := help

#------------------------------------------------------------------------------
# Configuration
#------------------------------------------------------------------------------

JQ           := jq
BATS         := bats
SHELLCHECK   := shellcheck
GO           := go

MCP_DIR      := src
MCP_BIN_DIR  := bin
TEST_DIR     := test

HOOKS_SCRIPTS := hooks/scripts

PLATFORMS := darwin/arm64 darwin/amd64 linux/amd64 linux/arm64
REPO      := e-roux/agent-plugin-make

VERSION := $(shell $(JQ) -r .version plugin.json 2>/dev/null || echo "unknown")

#------------------------------------------------------------------------------
# Phony Targets Declaration
#------------------------------------------------------------------------------

.PHONY: help sync fmt lint typecheck check qa clean distclean
.PHONY: test copilot-cli.test mcp.test mcp.build publish

#------------------------------------------------------------------------------
# High-Level Targets
#------------------------------------------------------------------------------

check: fmt lint
qa: check test
test: copilot-cli.test mcp.test

#------------------------------------------------------------------------------
# Setup
#------------------------------------------------------------------------------

sync:
	which $(BATS)       >/dev/null 2>&1 || brew install bats-core
	which $(SHELLCHECK) >/dev/null 2>&1 || brew install shellcheck
	which $(JQ)         >/dev/null 2>&1 || brew install jq
	which $(GO)         >/dev/null 2>&1 || brew install go

#------------------------------------------------------------------------------
# Code Quality
#------------------------------------------------------------------------------

fmt:
	which shfmt >/dev/null 2>&1 && shfmt -w -i 2 $(HOOKS_SCRIPTS)/ || true

lint:
	$(SHELLCHECK) $(HOOKS_SCRIPTS)/*.sh bin/mcp-banner.sh

typecheck:
	true

#------------------------------------------------------------------------------
# Testing
#------------------------------------------------------------------------------

copilot-cli.test:
	$(BATS) $(TEST_DIR)/copilot-cli/hooks.bats $(TEST_DIR)/copilot-cli/hooks_e2e.bats $(TEST_DIR)/copilot-cli/plugin_integrity.bats

mcp.test:
	cd $(MCP_DIR) && $(GO) test -v -count=1 ./...

#------------------------------------------------------------------------------
# Build & Publish
#------------------------------------------------------------------------------

mcp.build:
	for platform in $(PLATFORMS); do \
	  os=$${platform%%/*}; arch=$${platform##*/}; \
	  printf "Building mcp-banner-%s-%s...\n" "$$os" "$$arch"; \
	  cd $(MCP_DIR) && GOOS=$$os GOARCH=$$arch $(GO) build -ldflags="-s -w" \
	    -o ../bin/mcp-banner-$$os-$$arch . && cd ..; \
	done

publish: mcp.build
	gh release create "v$(VERSION)" $(MCP_BIN_DIR)/mcp-banner-* \
	  --title "v$(VERSION)" \
	  --notes-file CHANGELOG.md \
	  --latest
	printf "Released v%s\n" "$(VERSION)"

#------------------------------------------------------------------------------
# Cleanup
#------------------------------------------------------------------------------

clean:
	rm -rf hooks/logs/

distclean: clean
	rm -f bin/mcp-banner

#------------------------------------------------------------------------------
# Help
#------------------------------------------------------------------------------

help:
	printf "\033[36m"
	printf "╔═╗╔═╗╔═╗╔╗╔╔╦╗   ╔═╗╦  ╦ ╦╔═╗ ╦ ╔╗╔   ╔╦╗╔═╗╦╔ ╔═╗╔═╗ ╦ ╦  ╔═╗\n"
	printf "╠═╣║╠╗║╣ ║║║ ║    ╠═╝║  ║ ║║╠╗ ║ ║║║   ║║║╠═╣╠╩╗║╣ ╠╣  ║ ║  ║╣ \n"
	printf "╝ ╝╚═╝╚═╝╝╚╝ ╝    ╝  ╩═╝╚═╝╚═╝ ╩ ╝╚╝   ╝ ╝╝ ╝╝ ╝╚═╝╚   ╩ ╩═╝╚═╝\n"
	printf "\033[0m\n"
	printf "Usage: make [target]\n\n"
	printf "\033[1;35mSetup:\033[0m\n"
	printf "  sync              - Install required tools (bats, shellcheck, jq, go)\n"
	printf "\n"
	printf "\033[1;35mDev:\033[0m\n"
	printf "  fmt               - Format scripts with shfmt\n"
	printf "  lint              - Lint scripts with shellcheck\n"
	printf "  check             - fmt + lint\n"
	printf "  qa                - check + test (quality gate)\n"
	printf "\n"
	printf "\033[1;35mTest:\033[0m\n"
	printf "  test              - Run all tests\n"
	printf "  copilot-cli.test  - Run hook and integrity tests (bats)\n"
	printf "  mcp.test          - Run mcp-banner Go unit tests\n"
	printf "\n"
	printf "\033[1;35mBuild:\033[0m\n"
	printf "  mcp.build         - Cross-compile mcp-banner binaries for all platforms\n"
	printf "\n"
	printf "\033[1;35mRelease:\033[0m\n"
	printf "  publish           - Build binaries + create GitHub Release (v%s)\n" "$(VERSION)"
	printf "\n"
	printf "\033[1;35mClean:\033[0m\n"
	printf "  clean             - Remove log artifacts\n"
	printf "  distclean         - clean + remove untracked build artifacts\n"
