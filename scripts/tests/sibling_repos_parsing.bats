#!/usr/bin/env bats
# Exercises the "Checkout sibling repos" step's embedded shell logic exactly
# as it ships in the workflow files that carry it — extracted live via
# extract_step_script.py so these tests fail the moment the shipped script
# drifts from what's asserted here. `git` is mocked (records the resolved
# clone URL + target instead of touching the network), so the suite runs
# fully offline — no live external infrastructure, per AGENTS.md.
#
# Regression coverage: the bare-repo and repo:path forms must keep behaving
# exactly as before. New-capability coverage: owner/repo and owner/repo:path
# must resolve to the explicit owner, not the ffreis-org default — including
# with FLEET_READ_TOKEN set, which is the scenario where getting this wrong
# is a silent 403, not a 404 (credentials do not survive an HTTPS redirect).

load test_helper

setup() {
  SCRATCH="$(mktemp -d)"
  MOCK_BIN="$SCRATCH/bin"
  mkdir -p "$MOCK_BIN"

  # Mock `git`: records `clone <url> <target>` instead of touching the
  # network. Reads MOCK_CLONE_LOG from its environment so this script stays
  # static (single-quoted heredoc — no interpolation at write time).
  cat >"$MOCK_BIN/git" <<'MOCKEOF'
#!/usr/bin/env bash
if [[ "$1" == "clone" ]]; then
  shift
  args=("$@")
  n=${#args[@]}
  url="${args[$((n - 2))]}"
  target="${args[$((n - 1))]}"
  {
    echo "CLONE_URL=$url"
    echo "CLONE_TARGET=$target"
  } >>"$MOCK_CLONE_LOG"
  mkdir -p "$target"
  exit 0
fi
exec /usr/bin/git "$@"
MOCKEOF
  chmod +x "$MOCK_BIN/git"

  MOCK_CLONE_LOG="$SCRATCH/clone.log"
  : >"$MOCK_CLONE_LOG"
  export MOCK_CLONE_LOG
  export PATH="$MOCK_BIN:$PATH"

  GITHUB_WORKSPACE="$SCRATCH/work/repo"
  mkdir -p "$GITHUB_WORKSPACE"
  export GITHUB_WORKSPACE
}

teardown() {
  rm -rf "$SCRATCH"
}

clone_url() { grep '^CLONE_URL=' "$MOCK_CLONE_LOG" | tail -n1 | cut -d= -f2-; }
clone_target() { grep '^CLONE_TARGET=' "$MOCK_CLONE_LOG" | tail -n1 | cut -d= -f2-; }

# run_step <sibling-repos-value> <fleet-read-token>
# scan-fix(shellcheck:SC2030,SC2031): pass the two env values the extracted
# script needs as explicit prefix-assignments on the `run bash -c` command
# itself, instead of `export`-ing them earlier in the @test body — shellcheck
# treats a bats @test block as a subshell boundary and (correctly, in
# general) can't prove an export three lines up is still visible by the time
# a helper function reads it. Prefix-assignment keeps assignment and use on
# one command, so there's no boundary to reason about.
run_step() {
  local wf="$1" sibling_repos="$2" fleet_read_token="$3"
  local script
  script="$(extract_step_script "$wf" "Checkout sibling repos")"
  SIBLING_REPOS="$sibling_repos" FLEET_READ_TOKEN="$fleet_read_token" \
    run bash -c "$script"
}

@test "python-lock-sync.yml: bare repo name defaults to ffreis-org owner (regression)" {
  run_step "python-lock-sync.yml" "ffreis-stock-simulator" ""
  [ "$status" -eq 0 ]
  [ "$(clone_url)" = "https://github.com/ffreis-org/ffreis-stock-simulator.git" ]
  [ "$(clone_target)" = "$GITHUB_WORKSPACE/../ffreis-stock-simulator" ]
}

@test "python-lock-sync.yml: repo:path with nested slashes preserves the full path verbatim (regression)" {
  # The exact entry named in the task: parsing must split off the path at
  # the FIRST ':' before ever looking for '/', or this path (which itself
  # contains multiple '/') gets corrupted.
  run_step "python-lock-sync.yml" "ffreis-stock-simulator:../../stock/ffreis-stock-simulator" ""
  [ "$status" -eq 0 ]
  [ "$(clone_url)" = "https://github.com/ffreis-org/ffreis-stock-simulator.git" ]
  [ "$(clone_target)" = "$GITHUB_WORKSPACE/../../stock/ffreis-stock-simulator" ]
}

@test "python-lock-sync.yml: owner/repo clones from the explicit owner, not ffreis-org (new capability)" {
  run_step "python-lock-sync.yml" "FelipeFuhr/ffreis-python-onnx-model-converter" ""
  [ "$status" -eq 0 ]
  [ "$(clone_url)" = "https://github.com/FelipeFuhr/ffreis-python-onnx-model-converter.git" ]
  [ "$(clone_target)" = "$GITHUB_WORKSPACE/../ffreis-python-onnx-model-converter" ]
}

@test "python-lock-sync.yml: owner/repo:path combines explicit owner with a nested-slash path (new capability)" {
  run_step "python-lock-sync.yml" "FelipeFuhr/ffreis-stock-simulator:../../stock/ffreis-stock-simulator" ""
  [ "$status" -eq 0 ]
  [ "$(clone_url)" = "https://github.com/FelipeFuhr/ffreis-stock-simulator.git" ]
  [ "$(clone_target)" = "$GITHUB_WORKSPACE/../../stock/ffreis-stock-simulator" ]
}

@test "python-lock-sync.yml: authenticated clone URL carries the explicit owner, not ffreis-org (the real-world risk)" {
  # This is the exact failure mode described in the defect: credentials do
  # not survive an HTTPS redirect, so if either FelipeFuhr-owned sibling ever
  # goes private, an authenticated clone that still targets ffreis-org
  # follows the redirect unauthenticated and 403s.
  run_step "python-lock-sync.yml" "FelipeFuhr/ffreis-stock-simulator" "test-token-xyz"
  [ "$status" -eq 0 ]
  [ "$(clone_url)" = "https://x-access-token:test-token-xyz@github.com/FelipeFuhr/ffreis-stock-simulator.git" ]
}

@test "all six sibling-repos-capable workflows carry byte-identical parsing logic" {
  local base other wf
  base="$(extract_step_script "python-fmt.yml" "Checkout sibling repos")"
  for wf in python-lint.yml python-test.yml python-coverage.yml python-mutation.yml python-lock-sync.yml; do
    other="$(extract_step_script "$wf" "Checkout sibling repos")"
    [ "$base" = "$other" ]
  done
}
