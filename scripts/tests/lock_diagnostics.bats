#!/usr/bin/env bats
# Exercises the "Assert uv.lock is not stale" step's embedded shell logic
# exactly as it ships in python-lock-sync.yml — extracted live via
# extract_step_script.py so these tests fail the moment the shipped script
# drifts from what's asserted here. `uv` is mocked so the suite runs fully
# offline: `uv lock --check`'s exit code and `uv lock`'s regenerated content
# are both test-controlled.

load test_helper

setup() {
  SCRATCH="$(mktemp -d)"
  WORKDIR="$SCRATCH/work"
  mkdir -p "$WORKDIR"
  MOCK_BIN="$SCRATCH/bin"
  mkdir -p "$MOCK_BIN"

  # Mock `uv`: `lock --check` exits with $MOCK_UV_CHECK_EXIT; a bare `lock`
  # (regenerate) copies $MOCK_UV_REGEN_FILE over uv.lock and logs that it
  # ran, so tests can assert whether regeneration happened at all.
  cat >"$MOCK_BIN/uv" <<'MOCKEOF'
#!/usr/bin/env bash
if [[ "$1" == "lock" && "${2:-}" == "--check" ]]; then
  exit "${MOCK_UV_CHECK_EXIT:-0}"
fi
if [[ "$1" == "lock" ]]; then
  echo "REGENERATED" >>"$MOCK_UV_LOG"
  cp "$MOCK_UV_REGEN_FILE" uv.lock
  exit 0
fi
echo "unexpected uv invocation: $*" >&2
exit 99
MOCKEOF
  chmod +x "$MOCK_BIN/uv"
  export PATH="$MOCK_BIN:$PATH"

  MOCK_UV_LOG="$SCRATCH/uv.log"
  : >"$MOCK_UV_LOG"
  export MOCK_UV_LOG
}

teardown() {
  rm -rf "$SCRATCH"
}

# write_committed_lock <content>: seeds $WORKDIR/uv.lock as the "committed" file.
write_committed_lock() {
  printf '%s\n' "$1" >"$WORKDIR/uv.lock"
}

# run_step <check-exit-code> <regen-content-file>
# scan-fix(shellcheck:SC2030,SC2031): pass the two mock-control values as
# explicit prefix-assignments on the command that actually runs the
# extracted script, instead of `export`-ing them earlier in the @test body
# — shellcheck treats a bats @test block as a subshell boundary and can't
# prove an export a few lines up is still visible when a helper function
# reads it later. Prefix-assignment keeps assignment and use on one command.
run_step() {
  local check_exit="$1" regen_file="$2"
  local script
  script="$(extract_step_script "python-lock-sync.yml" "Assert uv.lock is not stale")"
  ( cd "$WORKDIR" && MOCK_UV_CHECK_EXIT="$check_exit" MOCK_UV_REGEN_FILE="$regen_file" bash -c "$script" )
}

@test "check succeeds: step exits 0 and never regenerates (happy path unaffected)" {
  write_committed_lock "same-content"
  run run_step 0 "$SCRATCH/unused.lock"
  [ "$status" -eq 0 ]
  [ ! -s "$MOCK_UV_LOG" ]
  [ "$(cat "$WORKDIR/uv.lock")" = "same-content" ]
}

@test "check fails: step still exits non-zero (diagnostics must never turn a failure green)" {
  write_committed_lock "committed-line-one"
  printf 'regenerated-line-one\n' >"$SCRATCH/regen.lock"
  run run_step 1 "$SCRATCH/regen.lock"
  [ "$status" -ne 0 ]
}

@test "check fails: prints an ::error:: annotation and the actual diff content" {
  write_committed_lock "committed-line-one"
  printf 'regenerated-line-one\n' >"$SCRATCH/regen.lock"
  run run_step 1 "$SCRATCH/regen.lock"
  [ "$status" -ne 0 ]
  [[ "$output" == *"::error::"* ]]
  [[ "$output" == *"-committed-line-one"* ]]
  [[ "$output" == *"+regenerated-line-one"* ]]
}

@test "check fails: committed uv.lock is restored, no scratch files left behind" {
  write_committed_lock "committed-line-one"
  printf 'regenerated-line-one\n' >"$SCRATCH/regen.lock"
  run run_step 1 "$SCRATCH/regen.lock"
  [ "$status" -ne 0 ]
  [ "$(cat "$WORKDIR/uv.lock")" = "committed-line-one" ]
  [ ! -e "$WORKDIR/uv.lock.committed-backup" ]
  [ ! -e "$WORKDIR/uv.lock.diagnostic-diff" ]
}

@test "check fails with a large diff: output is capped with a truncation note" {
  local committed regen i
  committed=""
  regen=""
  for i in $(seq 1 300); do
    committed+="committed-line-$i"$'\n'
    regen+="regenerated-line-$i"$'\n'
  done
  printf '%s' "$committed" >"$WORKDIR/uv.lock"
  printf '%s' "$regen" >"$SCRATCH/regen.lock"
  run run_step 1 "$SCRATCH/regen.lock"
  [ "$status" -ne 0 ]
  [[ "$output" == *"truncated"* ]]
  # The full unified diff for a 300/300-line rewrite is well over 200 lines;
  # confirm the printed diff body itself was capped rather than dumped whole.
  diff_body_lines="$(printf '%s\n' "$output" | grep -cE '^[+-](committed-line-|regenerated-line-)')"
  [ "$diff_body_lines" -le 200 ]
}
