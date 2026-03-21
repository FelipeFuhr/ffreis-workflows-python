.PHONY: help lint check fmt-check secrets-scan-staged lefthook-bootstrap lefthook-install hooks

WORKFLOWS_DIR := .github/workflows

## help: Show this help message
help:
	@echo "Available targets:"
	@grep -E '^## ' $(MAKEFILE_LIST) | sed 's/## /  /'

## lint: Validate workflow YAML + ruff on examples
lint:
	@echo "==> Validating workflow YAML files..."
	@for f in $(WORKFLOWS_DIR)/*.yml; do \
		python3 -c "import sys, yaml; yaml.safe_load(open('$$f'))" \
			&& echo "  OK: $$f" \
			|| { echo "  FAIL: $$f"; exit 1; }; \
	done
	@echo "All YAML files are valid."
	@if command -v uv > /dev/null 2>&1; then \
		cd examples/hello && uv run ruff check .; \
	else \
		echo "uv not found; skipping ruff lint on examples"; \
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
	gitleaks protect --staged --redact

## lefthook-bootstrap: Download lefthook binary to .bin/
lefthook-bootstrap:
	LEFTHOOK_VERSION="1.7.10" BIN_DIR=".bin" bash ./scripts/bootstrap_lefthook.sh

## lefthook-install: Install git hooks via lefthook
lefthook-install:
	lefthook install

## hooks: Bootstrap and install all git hooks
hooks: lefthook-bootstrap lefthook-install
