# Shared helpers for the bats suites in this directory.

# repo_root: absolute path to the repository root, derived from the running
# .bats file's own location so these tests work regardless of cwd.
repo_root() {
  cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd
}

# extract_step_script <workflow.yml> <step-name>
# Prints the named step's `run:` script exactly as it ships today, so tests
# fail the moment the shipped script drifts from what's asserted here.
extract_step_script() {
  local wf="$1" step="$2"
  python3 "$(repo_root)/scripts/tests/extract_step_script.py" \
    "$(repo_root)/.github/workflows/$wf" "$step"
}
