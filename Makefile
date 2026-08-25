.PHONY: help lint check fmt-check secrets-scan-staged lefthook-bootstrap lefthook-install hooks setup test-scripts

WORKFLOWS_DIR := .github/workflows

## help: Show this help message
help:
	@echo "Available targets:"
	@grep -E '^## ' $(MAKEFILE_LIST) | sed 's/## /  /'

## lint: Validate workflow YAML + ruff on examples + bats tests on embedded workflow scripts
lint:
	@echo "==> Validating workflow YAML files..."
	@if command -v yamllint > /dev/null 2>&1; then \
		yamllint -d '{extends: relaxed, rules: {line-length: {max: 160}}}' $(WORKFLOWS_DIR)/; \
		echo "All YAML files are valid."; \
	else \
		python3 -c "import yaml" >/dev/null 2>&1 || { \
			echo "ERROR: Neither yamllint nor PyYAML is available."; \
			echo "Install yamllint with 'pip install yamllint' or PyYAML with 'pip install pyyaml'."; \
			exit 1; \
		}; \
		for f in $(WORKFLOWS_DIR)/*.yml; do \
			python3 -c "import sys, yaml; yaml.safe_load(open('$$f'))" \
				&& echo "  OK: $$f" \
				|| { echo "  FAIL: $$f"; exit 1; }; \
		done; \
		echo "All YAML files are valid."; \
	fi
	@if command -v uv > /dev/null 2>&1; then \
		cd examples/hello && uv run ruff check .; \
	else \
		echo "uv not found; skipping ruff lint on examples"; \
	fi
	@$(MAKE) test-scripts

## test-scripts: Run bats tests covering the embedded workflow-step shell scripts
test-scripts:
	@echo "==> Running workflow script unit tests (bats)..."
	@if command -v bats > /dev/null 2>&1; then \
		bats scripts/tests/; \
	else \
		echo "bats not found; skipping workflow script unit tests."; \
		echo "Install bats from https://github.com/bats-core/bats-core#installation to run them locally."; \
	fi

## check: Run yamllint if available, otherwise fall back to lint
check:
	@if command -v yamllint > /dev/null 2>&1; then \
		echo "==> Running yamllint on $(WORKFLOWS_DIR)/..."; \
		yamllint -d '{extends: relaxed, rules: {line-length: {max: 160}}}' $(WORKFLOWS_DIR)/; \
	else \
		echo "yamllint not found — falling back to Python YAML validation."; \
		$(MAKE) lint; \
	fi

## fmt-check: Check Python example formatting with ruff
fmt-check:
	cd examples/hello && uv run ruff format --check .

## secrets-scan-staged: Scan staged files for secrets
secrets-scan-staged:
	@command -v gitleaks >/dev/null 2>&1 || { \
		echo "ERROR: gitleaks not found. Install it from https://github.com/gitleaks/gitleaks#installing"; \
		echo "Tip: run 'make setup' after installing to verify your dev environment."; \
		exit 1; \
	}
	gitleaks protect --staged --redact

## lefthook-bootstrap: Download lefthook binary to .bin/
lefthook-bootstrap:
	LEFTHOOK_VERSION="1.7.10" BIN_DIR=".bin" bash ./scripts/bootstrap_lefthook.sh

## lefthook-install: Install git hooks via lefthook
lefthook-install:
	lefthook install

## hooks: Bootstrap and install all git hooks
hooks: lefthook-bootstrap lefthook-install

## setup: Install git hooks and verify required tools
setup: hooks
	@command -v gitleaks >/dev/null 2>&1 || { \
		echo ""; \
		echo "ACTION REQUIRED: gitleaks is not installed."; \
		echo "Install it from https://github.com/gitleaks/gitleaks#installing then re-run 'make setup'."; \
		echo ""; \
		exit 1; \
	}
	@echo "Dev environment ready."

PLATFORM_STANDARDS_SHA ?= 3c787edb4e96ddea2e86b2add2c32139685e8db7  # v1.2.1
PLATFORM_STANDARDS_RAW ?= https://raw.githubusercontent.com/FelipeFuhr/ffreis-platform-standards

install-act: ## Download pinned act binary into .bin/
	@mkdir -p scripts
	@curl -fsSL "$(PLATFORM_STANDARDS_RAW)/$(PLATFORM_STANDARDS_SHA)/scripts/install_act.sh" \
		-o scripts/install_act.sh && chmod +x scripts/install_act.sh
	@bash ./scripts/install_act.sh

ci-local: ## Run workflows locally via act (GH Actions quota fallback). Args via ARGS=...
	@mkdir -p scripts
	@curl -fsSL "https://raw.githubusercontent.com/FelipeFuhr/ffreis-platform-ci-local/v1.0.0/scripts/run-ci-local.sh" \
		-o scripts/run-ci-local.sh && chmod +x scripts/run-ci-local.sh
	@CI_LOCAL_FINDINGS_REF=v1.0.0 PATH="$(CURDIR)/.bin:$(PATH)" bash ./scripts/run-ci-local.sh $(ARGS)
