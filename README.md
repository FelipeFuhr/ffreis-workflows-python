# ffreis-platform-workflows-python

<!-- ffreis-badges:start -->
[![CI](https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/FelipeFuhr/ffreis-badges/main/badges/ffreis-workflows-python/ci.json)](https://github.com/FelipeFuhr/ffreis-workflows-python/actions) [![Latest version](https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/FelipeFuhr/ffreis-badges/main/badges/ffreis-workflows-python/version.json)](https://github.com/FelipeFuhr/ffreis-workflows-python/releases) [![License](https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/FelipeFuhr/ffreis-badges/main/badges/ffreis-workflows-python/license.json)](https://github.com/FelipeFuhr/ffreis-workflows-python/blob/main/LICENSE)
<!-- ffreis-badges:end -->

Reusable GitHub Actions workflows for Python projects in the ffreis organisation.


All workflows use `on: workflow_call:` and should be consumed from other repos by pinning to a specific commit SHA for reproducibility and security. Example:

```yaml
uses: ffreis/ffreis-platform-workflows-python/.github/workflows/<file>.yml@<sha>
```

Replace `<sha>` with the latest commit SHA from the target workflow repository. Avoid using @main or @vX tags for production workflows.

---

## Workflows

| File | Purpose | Key Inputs |
|------|---------|------------|
| `python-fmt.yml` | `ruff format --check` | `python-version`, `working-directory`, `source-dirs`, `uv-extras` |
| `python-lint.yml` | `ruff check` + `mypy` | `python-version`, `working-directory`, `source-dirs`, `mypy-dirs`, `uv-extras` |
| `python-test.yml` | `pytest` unit + integration tests | `python-version`, `working-directory`, `uv-extras`, `uv-groups`, `test-dir`, `pytest-args`, `timeout-minutes`, `sibling-repos`, `coverage-min`, `integration-test-dir`, `integration-coverage-min`, `runner` |
| `python-build.yml` | Matrix build (OS x Python) | `python-versions`, `os-list`, `uv-extras`, `test-dir`, `build-command` |
| `python-security.yml` | `pip-audit` CVE scan | `python-version`, `working-directory` |
| `python-coverage.yml` | `pytest-cov` + Codecov upload | `python-version`, `working-directory`, `uv-extras`, `coverage-command`, `coverage-file`, `codecov-flags`, `codecov-name`; secret `CODECOV_TOKEN` |
| `python-container.yml` | Container image build (podman/docker) + smoke test | `image-name` (required), `containerfile`, `context`, `build-args` |
| `python-lock-sync.yml` | Assert `uv.lock` is not stale (`uv lock --check`) | `python-version`, `working-directory` |
| `python-hypothesis.yml` | Hypothesis property-based tests | `python-version`, `working-directory`, `uv-extras`, `test-dir`, `timeout-minutes`, `hypothesis-profile` |
| `python-semgrep.yml` | Semgrep SAST | `working-directory`, `config` |
| `python-docs.yml` | Build docs (mkdocs/sphinx) | `python-version`, `working-directory`, `uv-extras`, `docs-command` |
| `python-bench.yml` | `pytest-benchmark`, uploads JSON artifact | `python-version`, `working-directory`, `uv-extras`, `bench-dir`, `timeout-minutes` |

---

## Usage Examples

### Format check

```yaml
jobs:
  fmt:
    uses: ffreis/ffreis-platform-workflows-python/.github/workflows/python-fmt.yml@<sha> # latest
    with:
      source-dirs: "src tests"
```

### Lint (ruff + mypy)

```yaml
jobs:
  lint:
    uses: ffreis/ffreis-platform-workflows-python/.github/workflows/python-lint.yml@<sha> # latest
    with:
      source-dirs: "src tests"
      mypy-dirs: "src"
```

### Unit tests

```yaml
jobs:
  test:
    uses: ffreis/ffreis-platform-workflows-python/.github/workflows/python-test.yml@<sha> # latest
    with:
      test-dir: "tests/unit_tests"
      pytest-args: "-q --tb=short"
```

### Unit + integration coverage gates

`coverage-min` and `integration-coverage-min` are independent, opt-in gates
(each defaults to `0` = no enforcement, no extra cost). Setting
`integration-coverage-min` above `0` runs a second, separate pytest+coverage
invocation against `integration-test-dir`; if that directory doesn't exist
yet, the step logs a message and exits `0` instead of failing the job — safe
to enable fleet-wide before every repo has integration tests.

```yaml
jobs:
  test:
    uses: ffreis/ffreis-platform-workflows-python/.github/workflows/python-test.yml@<sha> # latest
    with:
      test-dir: "tests/unit_tests"
      coverage-min: 75
      integration-test-dir: "tests/integration_tests"
      integration-coverage-min: 75
```

### Matrix build

```yaml
jobs:
  build:
    uses: ffreis/ffreis-platform-workflows-python/.github/workflows/python-build.yml@<sha> # latest
    with:
      python-versions: '["3.13","3.11","3.10"]'
      os-list: '["ubuntu-latest","macos-latest"]'
```

### Security audit (scheduled weekly)

```yaml
on:
  schedule:
    - cron: "0 9 * * 1"
  workflow_dispatch:

jobs:
  security:
    uses: ffreis/ffreis-platform-workflows-python/.github/workflows/python-security.yml@<sha> # latest
```

### Coverage + Codecov

```yaml
jobs:
  coverage:
    uses: ffreis/ffreis-platform-workflows-python/.github/workflows/python-coverage.yml@<sha> # latest
    with:
      coverage-command: "uv run pytest --cov=src --cov-report=xml tests/unit_tests"
    secrets:
      CODECOV_TOKEN: ${{ secrets.CODECOV_TOKEN }}
```

### Container build

```yaml
jobs:
  container:
    uses: ffreis/ffreis-platform-workflows-python/.github/workflows/python-container.yml@<sha> # latest
    with:
      image-name: "my-app:latest"
      containerfile: "Containerfile"
```

### Lock sync check

```yaml
jobs:
  lock-sync:
    uses: ffreis/ffreis-platform-workflows-python/.github/workflows/python-lock-sync.yml@<sha> # latest
```

### Hypothesis property tests

```yaml
jobs:
  hypothesis:
    uses: ffreis/ffreis-platform-workflows-python/.github/workflows/python-hypothesis.yml@<sha> # latest
    with:
      test-dir: "tests/hypothesis_tests"
      hypothesis-profile: "ci"
```

### Semgrep SAST

```yaml
jobs:
  semgrep:
    uses: ffreis/ffreis-platform-workflows-python/.github/workflows/python-semgrep.yml@<sha> # latest
    with:
      config: "auto"
```

### Docs build

```yaml
jobs:
  docs:
    uses: ffreis/ffreis-platform-workflows-python/.github/workflows/python-docs.yml@<sha> # latest
    with:
      docs-command: "uv run mkdocs build --strict"
      uv-extras: "docs"
```

### Benchmarks (scheduled)

```yaml
on:
  schedule:
    - cron: "0 3 * * 0"
  workflow_dispatch:

jobs:
  bench:
    uses: ffreis/ffreis-platform-workflows-python/.github/workflows/python-bench.yml@<sha> # latest
    with:
      bench-dir: "benchmarks/"
```

---

## Conventions

- `actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd # v6`
- `actions/setup-python@a309ff8b426b58ec0e2a45f0f869d46889d02405 # v6.2.0`
- `astral-sh/setup-uv@eac588ad8def6316056a12d4907a9d4d84ff7a3b` (pinned SHA)
- All multi-line `run:` blocks begin with `set -euo pipefail`
- `uv.lock` presence is asserted before every `uv sync`
- `permissions: contents: read` on all jobs
- `concurrency` is intentionally omitted from reusable workflows — callers control it
