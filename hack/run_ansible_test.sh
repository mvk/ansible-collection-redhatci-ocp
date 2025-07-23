#!/usr/bin/env bash
#
# Copyright (C) 2025 Red Hat, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may
# not use this file except in compliance with the License. You may obtain
# a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations
# under the License.
SCRIPT_DEBUG="${SCRIPT_DEBUG:-0}"

TOPDIR="$(git rev-parse --show-toplevel || true)"
test -z "${TOPDIR}" && { echo "FATAL: This script expects to run from a specific git repository" >&2; exit 1; }
# shellcheck source=hack/common_lib.bash
source "${TOPDIR}/hack/common_lib.bash"

# --- OS Detection and Tool Setup ---
tools_setup "${OS}"
# --- End of OS Detection and Tool Setup ---

# enable bash code tracing when debugging
if [[ "${SCRIPT_DEBUG}" -gt 0 ]]; then
  set -o xtrace
fi
set -o errexit

RUN_IN_PARALLEL="${RUN_IN_PARALLEL:-0}"
if [[ "${RUN_IN_PARALLEL}" -gt 0 ]]; then
  log.info "This script was launched with RUN_IN_PARALLEL=${RUN_IN_PARALLEL}"
fi
# when run outside of a GitHub action
GITHUB_STEP_SUMMARY="${GITHUB_STEP_SUMMARY:-/dev/null}"

truncate -s 0 "source.output"
truncate -s 0 "target.output"

declare -a EXCLUDE

CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD || true)"
SOURCE_BRANCH="${SOURCE_BRANCH:-"branch"}"
TARGET_BRANCH="${TARGET_BRANCH:-"main"}"

# shellcheck disable=SC2064
trap "git checkout ${CURRENT_BRANCH}" EXIT

# Parse test types from arguments, default to all
TEST_TYPES=()
if [[ $# -eq 0 ]]; then
  TEST_TYPES=(
    sanity
    units
    integration
  )
else
  for arg in "$@"; do
    case "${arg}" in
      sanity|units|integration)
        TEST_TYPES+=("${arg}")
        ;;
      *)
        echo "Unknown test type: ${arg}"
        echo "Usage: $0 [sanity] [units] [integration]"
        exit 2
        ;;
    esac
  done
fi
declare -a TEST_PIDS
run_tests() {
  local \
    version \
    prefix
  local -a \
    cmd
  version="${1?cannot have version empty}"
  prefix="${2?cannot have prefix empty}"
  log.debug "In ${FUNCNAME[0]}('${version}', '${prefix}')"
  for test_type in "${TEST_TYPES[@]}"; do
    cmd=()
    # shellcheck disable=SC2249
    case "${test_type}" in
      sanity)
        cmd=(ansible-test "${test_type}" "${EXCLUDE[@]}" --verbose --docker --python "${version}" --color --coverage --failure-ok --lint)
        ;;
      units)
        cmd=(ansible-test "${test_type}" --verbose --docker --python "${version}" --color --coverage)
        ;;
      integration)
        cmd=(ansible-test "${test_type}" --verbose --docker --python "${version}" --color --coverage)
        ;;
    esac
    if [[ "${RUN_IN_PARALLEL}" -eq 0 ]]; then
      log.info "Running ${test_type} tests for ${version} sequentially"
      "${cmd[@]}" > "${prefix}.${test_type}.${version}.output" 2>&1 || true
    else
      log.info "Running ${test_type} tests for ${version} in parallel"
      ("${cmd[@]}" > "${prefix}.${test_type}.${version}.output" 2>&1 || true) &
      TEST_PIDS+=($!)
    fi
  done
}

PY_CODE="import re, sys; print(' '.join({m.group(1) for m in re.finditer(r'(3\.\d+)', sys.stdin.read()) if m.group(1) != '3.5'}))"
# extract all the supported python versions from the error message, excluding 3.5
EXCLUDE=("--exclude" "tests/" "--exclude" "hack/" "--exclude" "plugins/modules/nmcli.py")
mapfile -t PY_VERS < <(
  ansible-test sanity "${EXCLUDE[@]}" --verbose --docker --python 1.0 --color --coverage --failure-ok 2>&1 | \
  python -c "${PY_CODE}" | tr '[:space:]' '\n' | \
  sort -V || \
  true
)
# Tests in current (source) branch
log.info "Start running tests in source branch ${SOURCE_BRANCH}, this may take a while as no output is displayed..."
for version in "${PY_VERS[@]}"; do
  run_tests "${version}" "source"
done 2> >(tee -a source.output >&2 || true)
log.info "tests completed"

# Tests in target branch
run_cmd 0 git fetch origin "${TARGET_BRANCH}"
run_cmd 0 git checkout "${TARGET_BRANCH}" || true
log.info "Running tests in target branch ${TARGET_BRANCH}, this may take a while as no output is displayed..."
for version in "${PY_VERS[@]}"; do
  run_tests "${version}" "target"
done 2> >(tee -a target.output >&2 || true)

if [[ "${RUN_IN_PARALLEL}" -gt 0 ]]; then
  log.info "Waiting for tests to complete..."
  wait "${TEST_PIDS[@]}"
fi

log.info
for key in "source" "target"; do
  "${GREP}" -E "((ERROR|FATAL):|FAILED )" "${key}.output" |
  "${GREP}" -v "issue(s) which need to be resolved\|See error output above for details.\|Command \"ansible-doc -t module .*\" returned exit status .*\." |
  "${SED}" -r 's/\x1B\[[0-9]{1,2}[mGK]//g' > "${key}.errors"
done

# remove line numbers
"${SED}" -i -E -e 's/:[0-9]+:/:/' -e 's/:[0-9]+:/:/' {source,target}.errors

echo "## Improvements are listed below" | tee -a "${GITHUB_STEP_SUMMARY}"
echo "\`\`\`diff" >> "${GITHUB_STEP_SUMMARY}"
diff -u0 {source,target}.errors | "${GREP}" '^+[^+]' | "${SED}" -e 's/ERROR/FIXED/' | tee -a "${GITHUB_STEP_SUMMARY}"
echo "\`\`\`" >> "${GITHUB_STEP_SUMMARY}"
echo "## Regressions are listed below" | tee -a "${GITHUB_STEP_SUMMARY}"
echo "\`\`\`diff" >> "${GITHUB_STEP_SUMMARY}"
diff -u0 {source,target}.errors | "${GREP}" '^-[^-]' | tee -a "${GITHUB_STEP_SUMMARY}"
echo "\`\`\`" >> "${GITHUB_STEP_SUMMARY}"

rc=0
if diff -u0 {source,target}.errors | "${GREP}" -q '^-[^-]'; then
   echo "> Fix the regression errors listed above" | tee -a "${GITHUB_STEP_SUMMARY}"
   rc=1
fi

exit "${rc}"
# run_ansible_test.sh ends here
