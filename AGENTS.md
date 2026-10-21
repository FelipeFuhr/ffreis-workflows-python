# ffreis-workflows-python — contribution guide

This repository is a library of reusable GitHub Actions workflows for Python projects.
The `examples/hello/` directory is the canonical test subject used by `self-test.yml`.

---

## Rules for adding or modifying workflows

### 1. Every new workflow must be in `self-test.yml`

Every file added to `.github/workflows/` (except `self-test.yml` itself) **must** have a
corresponding job in `self-test.yml` that calls it against `examples/hello/`.

A workflow that is not exercised by `self-test.yml` is unverified. It will not be merged.

**Exception — repo-internal DevOps workflows** (`devops-*.yml`): these files manage the
repository itself (security scanning, PR hygiene, release automation) and are event-triggered.
They cannot use `workflow_call` and therefore cannot be invoked from `self-test.yml`. New
`devops-*.yml` files are exempt from the self-test requirement. All other workflows here
operate on source code and do not require live external infrastructure.

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

### 7. `python-mutation.yml`'s `in-diff` is file-level, and `--paths-to-mutate` is comma/colon-separated, never space-separated

mutmut has no native diff/incremental mode — confirmed directly against the CLI
(`mutmut run --help`, 2.5.1 through the current 3.8.0 latest: no diff flag exists
at any version). `in-diff` is therefore a FILE-level approximation: it computes
the PR's changed `.py` files itself (`git diff --merge-base`) and hands that list
to `--paths-to-mutate`, not a true line-level diff the way cargo-mutants'
`--in-diff` is for Rust.

`--paths-to-mutate` itself takes a COMMA- or COLON-separated list — confirmed
directly: passing a SPACE-separated value (the convention every other language's
mutation workflow in this fleet uses — gremlins' `packages`, cargo-mutants' `-p`)
is REJECTED outright with "Error: You must specify a list of paths to mutate",
not silently mis-parsed. The diff-computed file list is comma-joined to match;
do not "fix" it to space-separated to match the other languages' convention.

An empty diff (nothing under `paths-to-mutate` changed) must skip mutmut
entirely rather than call it with an empty `--paths-to-mutate` — that is a hard,
loud CLI failure, not a vacuous pass. It also must not be allowed to fall through
to the scorer's missing-`.mutmut-cache` branch, which is a DELIBERATE hard FAIL
("A gate that cannot measure must FAIL, never pass" — see that step's own
comment): an empty diff is a different, legitimate "nothing to check" case, and
is its own explicit early-exit branch in the scorer, checked before the
missing-cache check.

This repo's own `self-test.yml` runs on `push: branches: [main]` only, and
`in-diff`'s effective condition is `github.event_name == 'pull_request'` — a
self-test job that sets `in-diff: true` therefore silently runs the ordinary
full-scope path instead. A green self-test run is not proof `in-diff` itself
works; it was validated via `act` against a throwaway harness instead (real
untested functions across multiple files, a synthetic `pull_request` event) —
see the PR that introduced this input for the transcript.

Requires `mutmut>=2.4,<3` — see the workflow file's own header comment.

---

## Makefile targets

| Target | Purpose |
|---|---|
| `make setup` | Bootstrap lefthook + verify all required dev tools are installed |
| `make lint` | Validate workflow YAML + ruff on `examples/hello` |
| `make fmt-check` | Check Python formatting with ruff |
| `make secrets-scan-staged` | Scan staged files with gitleaks (fails if gitleaks not installed) |
| `make hooks` | Install git hooks via lefthook |
