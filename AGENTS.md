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

**Handling optional secrets** — if a workflow uses a secret that may not always be present
(e.g. `SONAR_TOKEN`, `CODECOV_TOKEN`), implement graceful-skip via output-based gating so
the workflow always runs in CI, but skips only the token-dependent step:

```yaml
- name: Check token
  id: gate
  env:
    TOKEN: ${{ secrets.SOME_TOKEN }}
  run: |
    if [ -z "${TOKEN}" ]; then
      echo "::notice::TOKEN not set — skipping. Add the secret to enable."
      echo "skip=true" >> "$GITHUB_OUTPUT"
    else
      echo "skip=false" >> "$GITHUB_OUTPUT"
    fi

- name: Do the thing
  if: steps.gate.outputs.skip != 'true'
  ...
```

Pass the secret explicitly in `self-test.yml` — it will be absent in forks/PRs without the
secret configured, triggering the skip path, which is the correct behaviour:

```yaml
sonar:
  uses: ./.github/workflows/python-sonar.yml
  with:
    working-directory: examples/hello
  secrets:
    SONAR_TOKEN: ${{ secrets.SONAR_TOKEN }}
```

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
workflows. Use output-based gating instead (see the graceful-skip pattern in rule 1).

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
uses: SonarSource/sonarqube-scan-action@a31c9398be7ace6bbfaf30c0bd5d415f843d45e9 # nosemgrep: generic.secrets.security.detected-sonarqube-docs-api-key
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
