#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

timeout_seconds="${CI_TEST_TIMEOUT_SECONDS:-600}"
if ! [[ "${timeout_seconds}" =~ ^[0-9]+$ ]] || (( timeout_seconds < 1 )); then
    echo "[ci-tests] CI_TEST_TIMEOUT_SECONDS must be a positive integer. Got: ${timeout_seconds}" >&2
    exit 2
fi

command=(swift test -Xswiftc -warnings-as-errors)
test_pid=""
log_file="$(mktemp "${TMPDIR:-/tmp}/vox-ci-tests.XXXXXX")"

if [[ "${VOX_ENABLE_INTEGRATION_TESTS:-0}" != "1" ]]; then
    export DEEPGRAM_API_KEY=""
fi

terminate_test_processes() {
    local signal="$1"
    [[ -n "${test_pid}" ]] || return 0
    kill -"${signal}" "${test_pid}" 2>/dev/null || true
    pkill -"${signal}" -P "${test_pid}" 2>/dev/null || true
    pkill -"${signal}" -f "/usr/bin/xctest .*VoxPackageTests\\.xctest" 2>/dev/null || true
    pkill -"${signal}" -f "swift test -Xswiftc -warnings-as-errors" 2>/dev/null || true
}

cleanup() {
    if [[ -n "${test_pid}" ]] && kill -0 "${test_pid}" 2>/dev/null; then
        terminate_test_processes TERM
        sleep 1
        terminate_test_processes KILL
    fi
    rm -f "${log_file}"
}

handle_interrupt() {
    local signal="$1"
    echo "[ci-tests] Received ${signal}. Terminating test process tree..." >&2
    terminate_test_processes TERM
    sleep 1
    terminate_test_processes KILL
    exit 130
}

trap cleanup EXIT
trap 'handle_interrupt SIGINT' INT
trap 'handle_interrupt SIGTERM' TERM

echo "[ci-tests] Running: ${command[*]}"
echo "[ci-tests] Timeout: ${timeout_seconds}s"
if [[ "${VOX_ENABLE_INTEGRATION_TESTS:-0}" != "1" ]]; then
    echo "[ci-tests] Integration tests disabled (set VOX_ENABLE_INTEGRATION_TESTS=1 to enable)."
fi

set +e
"${command[@]}" > >(tee "${log_file}") 2>&1 &
test_pid=$!
start_time=$SECONDS
timed_out=0
poll_interval_seconds=1
next_heartbeat_seconds=30

while kill -0 "${test_pid}" 2>/dev/null; do
    elapsed=$((SECONDS - start_time))
    if (( elapsed >= next_heartbeat_seconds )); then
        echo "[ci-tests] still running (${elapsed}s elapsed)..."
        next_heartbeat_seconds=$((next_heartbeat_seconds + 30))
    fi

    if (( elapsed >= timeout_seconds )); then
        timed_out=1
        echo "[ci-tests] Timeout reached after ${elapsed}s. Terminating swift test (pid=${test_pid})." >&2
        terminate_test_processes TERM
        sleep 5
        terminate_test_processes KILL
        break
    fi
    sleep "${poll_interval_seconds}"
done

wait "${test_pid}"
test_status=$?
set -e

if (( timed_out == 1 )); then
    echo "::error::swift test exceeded ${timeout_seconds}s timeout"
    echo "[ci-tests] Active test-related processes:"
    ps -axo pid,etime,command | grep -E "swift test|xctest" | grep -v grep || true
    echo "[ci-tests] Last 200 log lines before timeout:"
    tail -n 200 "${log_file}" || true
    exit 124
fi

if (( test_status != 0 )); then
    echo "[ci-tests] swift test failed with exit code ${test_status}" >&2
    exit "${test_status}"
fi

echo "[ci-tests] OK"
