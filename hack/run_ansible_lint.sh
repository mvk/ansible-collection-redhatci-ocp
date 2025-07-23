#!/usr/bin/env bash
set +e

TOPDIR="$(git rev-parse --show-toplevel || true)"
test -z "${TOPDIR}" && { echo "FATAL: This script expects to run from a specific git repository" >&2; exit 1; }
# shellcheck source=hack/common_lib.bash
source "${TOPDIR}/hack/common_lib.bash"

# --- OS Detection and Tool Setup ---
tools_setup "${OS}"
# --- End of OS Detection and Tool Setup ---

SOURCE_BRANCH="${SOURCE_BRANCH:-"branch"}"
TARGET_BRANCH="${TARGET_BRANCH:-"main"}"

# enable bash code tracing when debugging
if [[ "${SCRIPT_DEBUG}" -gt 0 ]]; then
  set -o xtrace
fi

# when run outside of a GitHub action
GITHUB_STEP_SUMMARY="${GITHUB_STEP_SUMMARY:-"/dev/null"}"
truncate -s 0 source.output || true
truncate -s 0 target.output || true

# fix randomness
export PYTHONHASHSEED=42
git checkout -b "${SOURCE_BRANCH}"
# shellcheck disable=SC2064
trap "git checkout ${SOURCE_BRANCH}" EXIT
git fetch --unshallow origin "${TARGET_BRANCH}" || true
declare -a CMD
CMD=("hack/ansible-lint.sh" "-d")
# don't want to annotate through GHA
unset GITHUB_ACTIONS
echo "=== Incoming branch ${SOURCE_BRANCH} ==="
run_cmd 0 "${CMD[@]}" | tee "source.output"
git checkout "${TARGET_BRANCH}"
echo "=== Target branch ${TARGET_BRANCH} ==="
run_cmd 0 "${CMD[@]}" | tee "target.output"
export GITHUB_ACTIONS=true
# disable bash code tracing when debugging
if [[ "${SCRIPT_DEBUG}" -gt 0 ]]; then
  set +o xtrace
fi

# remove line numbers using the portable SED command
# Note: gsed -i works just like GNU sed, so this is safe.
"${SED}" -i 's/:[0-9]+:/::/' {source,target}.output

# export diff sans headers
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
