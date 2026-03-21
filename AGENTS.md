# ffreis-workflows-python — contribution guide

This repository is a library of reusable GitHub Actions workflows for Python projects.
The `examples/hello/` directory is the canonical test subject used by `self-test.yml`.

---

## Rules for adding or modifying workflows

### 1. Every new workflow must be in `self-test.yml`

Every file added to `.github/workflows/` (except `self-test.yml` itself) **must** have a
corresponding job in `self-test.yml` that calls it against `examples/hello/`.

A workflow that is not exercised by `self-test.yml` is unverified. It will not be merged.

**There are no exceptions in this repo.** All workflows here operate on source code and
do not require live external infrastructure.

**Handling required secrets** — if a workflow requires a secret (e.g. `SONAR_TOKEN`,
`CODECOV_TOKEN`), declare it as `required: true` in the workflow. In `self-test.yml`, gate
the entire job so it is explicitly skipped on fork PRs (where secrets are unavailable):

```yaml
sonar:
  if: github.event_name != 'pull_request' || github.event.pull_request.head.repo.fork == false
  uses: ./.github/workflows/python-sonar.yml
  with:
    working-directory: examples/hello
  secrets:
    SONAR_TOKEN: ${{ secrets.SONAR_TOKEN }}
```

This produces an explicit "Skipped" status on fork PRs rather than a silent success.

---

### 2. No silent failures

A step that fails silently is worse than one that fails loudly.

- If a required tool is missing → `exit 1` with a clear install message pointing to docs.
- If a required secret is absent and the workflow cannot meaningfully skip → fail the job.
- Never print a warning and continue when the operation did not run.

`make secrets-scan-staged` and `make setup` in the `Makefile` are the reference
implementation of the correct error pattern.

---

### 3. No shell injection — inputs go through `env:`

Never interpolate `${{ inputs.* }}`, `${{ github.* }}`, or any expression directly inside a
`run:` step. Always route through an `env:` variable. Semgrep runs in CI and will block PRs
that violate this rule (`run-shell-injection`).

```yaml
# BAD — Semgrep blocks this
run: uv sync --extra "${{ inputs.uv-extras }}"

# GOOD
env:
  UV_EXTRAS: ${{ inputs.uv-extras }}
run: uv sync --extra "$UV_EXTRAS"
```

---

### 4. Least-privilege secrets — never `secrets: inherit`

Pass only the secrets a workflow explicitly declares, both in `self-test.yml` and in any
downstream consumer:

```yaml
# BAD
uses: ./.github/workflows/python-sonar.yml
secrets: inherit

# GOOD
uses: ./.github/workflows/python-sonar.yml
secrets:
  SONAR_TOKEN: ${{ secrets.SONAR_TOKEN }}
```

---

### 5. `secrets.*` is forbidden in `if:` conditions

GitHub Actions forbids `secrets.*` in `if:` expressions within `workflow_call` reusable
workflows. Use job-level `if:` gating in `self-test.yml` instead (see the pattern in rule 1).

---

### 6. Pin third-party actions to a full commit SHA

```yaml
# BAD
uses: actions/checkout@v4

# GOOD
uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683 # v4
```

When Semgrep flags a SHA as a false-positive secret, suppress it inline:

```yaml
uses: SonarSource/sonarqube-scan-action@<sha> # nosemgrep: generic.secrets.security.detected-sonarqube-docs-api-key.detected-sonarqube-docs-api-key
```

---

## Makefile targets

| Target | Purpose |
|---|---|
| `make setup` | Bootstrap lefthook + verify all required dev tools are installed |
| `make lint` | Validate workflow YAML + ruff on `examples/hello` |
| `make fmt-check` | Check Python formatting with ruff |
| `make secrets-scan-staged` | Scan staged files with gitleaks (fails if gitleaks not installed) |
| `make hooks` | Install git hooks via lefthook |
