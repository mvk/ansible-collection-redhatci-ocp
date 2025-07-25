#!/usr/bin/env bash
SCRIPT_DEBUG="${SCRIPT_DEBUG:-"0"}"
set +e

TOPDIR="$(git rev-parse --show-toplevel || true)"
test -z "${TOPDIR}" && { echo "FATAL: This script expects to run from a specific git repository" >&2; exit 1; }
# shellcheck source=hack/common_lib.bash
source "${TOPDIR}/hack/common_lib.bash"

# --- OS Detection and Tool Setup ---
utils.tools_setup "$(uname -s || true)"
# --- End of OS Detection and Tool Setup ---

# --- Variables
# SOURCE_BRANCH: the source branch to run the tests on (default: current branch)
SOURCE_BRANCH="${SOURCE_BRANCH:-"$(git rev-parse --abbrev-ref HEAD || true)"}"
# TARGET_BRANCH: the target branch to compare the tests against (default: main)
TARGET_BRANCH="${TARGET_BRANCH:-"main"}"
# --- End of Variables

# enable bash code tracing when debugging
if [[ "${SCRIPT_DEBUG}" -gt 0 ]]; then
  set -o xtrace
fi

# when run outside of a GitHub action
GITHUB_STEP_SUMMARY="${GITHUB_STEP_SUMMARY:-"/dev/null"}"
utils.run_cmd 0 truncate -s 0 source.output || true
utils.run_cmd 0 truncate -s 0 target.output || true

# fix randomness
export PYTHONHASHSEED=42
declare -a CMD
CMD=("hack/ansible-lint.sh" "-d")
GIT_SYNC="${GIT_SYNC:-1}"

# shellcheck disable=SC2064
trap "git checkout ${SOURCE_BRANCH}" EXIT
# don't want to annotate through GHA
GHA_OLD="${GITHUB_ACTIONS}"
if [[ -n "${GITHUB_ACTIONS}" ]]; then
  unset GITHUB_ACTIONS
fi
echo "=== Incoming branch ${SOURCE_BRANCH} ==="
switch_to_branch "${SOURCE_BRANCH}"
utils.run_cmd 0 "${CMD[@]}" | tee "source.output"

echo "=== Target branch ${TARGET_BRANCH} ==="
switch_to_branch "${TARGET_BRANCH}"
utils.run_cmd 0 "${CMD[@]}" | tee "target.output"
export GITHUB_ACTIONS="${GHA_OLD}"
# disable bash code tracing when debugging
if [[ "${SCRIPT_DEBUG}" -gt 0 ]]; then
  set +o xtrace
fi

# remove line numbers using the portable SED command
# Note: gsed -i works just like GNU sed, so this is safe.
"${SED}" -i 's/:[0-9]+:/::/' {source,target}.output

# export diff without headers
diff -u0 {source,target}.output | tail -n +3 > diff.raw

# Get warnings out of the diff using the portable GREP command
"${GREP}" '\x1B\[33m|\(warning\)(\x1B\[0m)?$' diff.raw > diff.warnings
"${GREP}" -v '\x1B\[33m|\(warning\)(\x1B\[0m)?$' diff.raw > diff.output

echo "## Improvements over target branch ${TARGET_BRANCH}:" | tee -a "${GITHUB_STEP_SUMMARY}"
echo '```diff' >> "${GITHUB_STEP_SUMMARY}"
"${GREP}" '^+' diff.output |
  "${SED}" -e 's/^+/+FIXED: /' |
  # This sed command for stripping color codes is compatible with both GNU and BSD sed
  "${SED}" 's/\x1B\[[0-9;]*[mGKH]//g' |
  tee -a "${GITHUB_STEP_SUMMARY}"
echo '```' >> "${GITHUB_STEP_SUMMARY}"

echo "## Regressions from target branch ${TARGET_BRANCH}:" | tee -a "${GITHUB_STEP_SUMMARY}"
echo '```diff' >> "${GITHUB_STEP_SUMMARY}"
"${GREP}" '^-' diff.output |
  "${SED}" -e 's/^-/-ERROR: /' |
  "${SED}" 's/\x1B\[[0-9;]*[mGKH]//g' |
  tee -a "${GITHUB_STEP_SUMMARY}"
echo '```' >> "${GITHUB_STEP_SUMMARY}"

echo "## Warnings from target branch ${TARGET_BRANCH}:" | tee -a "${GITHUB_STEP_SUMMARY}"
echo '```diff' >> "${GITHUB_STEP_SUMMARY}"
"${GREP}" '^-' diff.warnings |
  "${SED}" -e 's/^-/-WARNING: /' |
  "${SED}" 's/\x1B\[[0-9;]*[mGKH]//g' |
  tee -a "${GITHUB_STEP_SUMMARY}"
echo '```' >> "${GITHUB_STEP_SUMMARY}"

if "${GREP}" -q '^-' diff.output; then
    echo "> Fix regressions listed above" | tee -a "${GITHUB_STEP_SUMMARY}"
    exit 1
fi
exit 0
