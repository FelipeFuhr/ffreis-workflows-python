# ffreis-platform-workflows-python

Reusable GitHub Actions workflows for Python projects in the ffreis organisation.

All workflows use `on: workflow_call:` and are consumed from other repos with:

```yaml
uses: ffreis/ffreis-platform-workflows-python/.github/workflows/<file>.yml@main
```

---

## Workflows

| File | Purpose | Key Inputs |
|------|---------|------------|
| `python-fmt.yml` | `ruff format --check` | `python-version`, `working-directory`, `source-dirs`, `uv-extras` |
| `python-lint.yml` | `ruff check` + `mypy` | `python-version`, `working-directory`, `source-dirs`, `mypy-dirs`, `uv-extras` |
| `python-test.yml` | `pytest` unit tests | `python-version`, `working-directory`, `uv-extras`, `test-dir`, `pytest-args`, `timeout-minutes` |
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
    uses: ffreis/ffreis-platform-workflows-python/.github/workflows/python-fmt.yml@main
    with:
      source-dirs: "src tests"
```

### Lint (ruff + mypy)

```yaml
jobs:
  lint:
    uses: ffreis/ffreis-platform-workflows-python/.github/workflows/python-lint.yml@main
    with:
      source-dirs: "src tests"
      mypy-dirs: "src"
```

### Unit tests

```yaml
jobs:
  test:
    uses: ffreis/ffreis-platform-workflows-python/.github/workflows/python-test.yml@main
    with:
      test-dir: "tests/unit_tests"
      pytest-args: "-q --tb=short"
```

### Matrix build

```yaml
jobs:
  build:
    uses: ffreis/ffreis-platform-workflows-python/.github/workflows/python-build.yml@main
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
    uses: ffreis/ffreis-platform-workflows-python/.github/workflows/python-security.yml@main
```

### Coverage + Codecov

```yaml
jobs:
  coverage:
    uses: ffreis/ffreis-platform-workflows-python/.github/workflows/python-coverage.yml@main
    with:
      coverage-command: "uv run pytest --cov=src --cov-report=xml tests/unit_tests"
    secrets:
      CODECOV_TOKEN: ${{ secrets.CODECOV_TOKEN }}
```

### Container build

```yaml
jobs:
  container:
    uses: ffreis/ffreis-platform-workflows-python/.github/workflows/python-container.yml@main
    with:
      image-name: "my-app:latest"
      containerfile: "Containerfile"
```

### Lock sync check

```yaml
jobs:
  lock-sync:
    uses: ffreis/ffreis-platform-workflows-python/.github/workflows/python-lock-sync.yml@main
```

### Hypothesis property tests

```yaml
jobs:
  hypothesis:
    uses: ffreis/ffreis-platform-workflows-python/.github/workflows/python-hypothesis.yml@main
    with:
      test-dir: "tests/hypothesis_tests"
      hypothesis-profile: "ci"
```

### Semgrep SAST

```yaml
jobs:
  semgrep:
    uses: ffreis/ffreis-platform-workflows-python/.github/workflows/python-semgrep.yml@main
    with:
      config: "auto"
```

### Docs build

```yaml
jobs:
  docs:
    uses: ffreis/ffreis-platform-workflows-python/.github/workflows/python-docs.yml@main
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
    uses: ffreis/ffreis-platform-workflows-python/.github/workflows/python-bench.yml@main
    with:
      bench-dir: "benchmarks/"
```

---

## Conventions

- `actions/checkout@v6`
- `actions/setup-python@v6`
- `astral-sh/setup-uv@eac588ad8def6316056a12d4907a9d4d84ff7a3b` (pinned SHA)
- All multi-line `run:` blocks begin with `set -euo pipefail`
- `uv.lock` presence is asserted before every `uv sync`
- `permissions: contents: read` on all jobs
- `concurrency` is intentionally omitted from reusable workflows — callers control it
