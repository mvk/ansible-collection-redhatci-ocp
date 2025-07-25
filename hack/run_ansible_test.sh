#!/usr/bin/env bash
# shellcheck disable=SC2310,SC2064
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

################################################################################
# --- Constants ---
################################################################################
# ANSIBLE_TEST_PARAMS: default parameters for the ansible-test command
declare -a ANSIBLE_TEST_PARAMS
ANSIBLE_TEST_PARAMS=(
  --verbose
  --docker
  --color
  --coverage
)
readonly -a ANSIBLE_TEST_PARAMS
# TEST_TYPES_SUPPORTED: supported test types
declare -a TEST_TYPES_SUPPORTED
TEST_TYPES_SUPPORTED=(
  units
  sanity
  integration
)
readonly -a TEST_TYPES_SUPPORTED
# ANSIBLE_TEST_EXCLUDES: default excludes for the command 'ansible-test sanity ...'
declare -a ANSIBLE_TEST_EXCLUDES
ANSIBLE_TEST_EXCLUDES=(
  "--exclude" "tests/"
  "--exclude" "hack/"
  "--exclude" "plugins/modules/nmcli.py"
)
readonly -a ANSIBLE_TEST_EXCLUDES
################################################################################
# --- End of Constants ---
################################################################################

################################################################################
# --- Global Variables
################################################################################
# SCRIPT_DEBUG: bulk increase of the code tracing/debugging (default: 0 - no, 1 - yes, 2 - even more)
SCRIPT_DEBUG="${SCRIPT_DEBUG:-0}"
# enable bash code tracing when debugging
if [[ "${SCRIPT_DEBUG}" -gt 0 ]]; then
  set -o xtrace
fi
################################################################################
# --- End of Global Variables
################################################################################
# --- Loading Libraries ---
# TOPDIR: the top directory of the repository (default: current directory)
TOPDIR="${TOPDIR:-"$(git rev-parse --show-toplevel || true)"}"
test -n "${TOPDIR}" || { echo "FATAL: This script must run in a git repository" >&2; exit 1; }
# BASH_LIBS: the directories to load the bash libraries from (default: hack)
declare -a BASH_LIBS
BASH_LIBS=(
  "${TOPDIR}/hack"
)
# Iterate over the bash libraries directories and load the libraries
for lib_dir in "${BASH_LIBS[@]}"; do
  while read -r lib_file; do
    # this means you can disable library loading by chmod 000 the file
    test -r "${lib_file}" || { echo "WARNING: bash library file is unreadable" >&2; continue; }
    # shellcheck disable=SC1090
    source "${lib_file}" 2>/dev/null || { echo "FATAL: failed sourcing ${lib_file}"; exit 1; }
  done < <(find "${lib_dir}" -type f -name "*.bash" || true)
done
# --- End of Loading Libraries ---

################################################################################
# --- Variables
################################################################################
# PRE_TEST_PATCHES_TXT: comma separated list of .patch files to apply before running tests (default: empty string)
PRE_TEST_PATCHES_TXT="${PRE_TEST_PATCHES:-""}"
# PRE_TEST_PATCHES: array of .patch files to apply before running tests (default: empty array)
declare -a PRE_TEST_PATCHES
IFS=',' read -r -a PRE_TEST_PATCHES <<<"${PRE_TEST_PATCHES_TXT}"
# GIT_SYNC: sync the branch with the origin before switching to it (default: 0 - no)
GIT_SYNC="${GIT_SYNC:-"1"}"
# PARALLEL: run the tests in parallel (default: 0 - no)
PARALLEL="${PARALLEL:-0}"
# GITHUB_STEP_SUMMARY: where to write the regression report (default: /dev/null)
GITHUB_STEP_SUMMARY="${GITHUB_STEP_SUMMARY:-/dev/null}"
# PY_VERS_EXCL: exclude a list of these Python versions from the tests (default: ['3.5'])
PY_VERS_EXCL="${PY_VERS_EXCL:-"['3.5']"}"
# PY_CODE: Python code to extract the Python versions from the error message
PY_CODE="${PY_CODE:-"import re, sys; print(' '.join({m.group(1) for m in re.finditer(r'(3\\.\\d+)', sys.stdin.read()) if m.group(1) not in set(${PY_VERS_EXCL})}))"}"
# REMOTE: the remote to use for the tests (default: current remote, if not found, use origin)
REMOTE="${REMOTE:-"$(git remote | head -n 1 || true)"}"
log.debug "Using git remote: ${REMOTE}"
# TEST_TYPES: default test types to run
declare -a TEST_TYPES
# TEST_PIDS: array of PIDs to wait on (only when PARALLEL > 0)
if [[ "${PARALLEL}" -gt 0 ]]; then
  log.info "This script was launched with PARALLEL=${PARALLEL}"
  declare -a TEST_PIDS
fi

# --- Last variables: ---
CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD || true)"
log.debug "Current branch detected: '${CURRENT_BRANCH}'"
# SOURCE_BRANCH: the source branch to run the tests on (default: current branch)
SOURCE_BRANCH="${SOURCE_BRANCH:-"${CURRENT_BRANCH}"}"
# TARGET_BRANCH: the target branch to compare the tests against (default: main)
TARGET_BRANCH="${TARGET_BRANCH:-"main"}"
log.debug "Source branch: '${SOURCE_BRANCH}'"
log.debug "Target branch: '${TARGET_BRANCH}'"
# --- End of Last variables: ---

# print the usage of the script
function print_usage(){
  local \
    rc
  rc="${1:-0}"
  echo "Usage: $0 [$(join_by "] [" "${TEST_TYPES_SUPPORTED[@]}" || true)]"
  exit "${rc}"
}

# setup the test types
function setup_test_types() {
  local -n \
    test_types_var
  local \
    test_type
  local -a \
    args
  test_types_var="${1?cannot continue without test_types_var}"
  shift 1
  args=("${@}")

  if [[ "${#args[@]}" -eq 0 ]]; then
    test_types_var=("${TEST_TYPES_SUPPORTED[@]}")
    return 0
  fi

  set +o errexit
  for test_type in "${args[@]}"; do
    if ! contains_element "${test_type}" "${TEST_TYPES_SUPPORTED[@]}"; then
      log.error "Unknown test_type: ${test_type}."
      print_usage 2
    fi
    test_types_var+=("${arg}")
  done
  set -o errexit
  return 0
}

# run the tests for a given option, version, and test types
function run_tests() {
  local \
    prefix \
    version \
    test_type \
    report_file \
    rc
  local -n \
    pids_collector_ref \
    test_params_ref \
    test_types_ref
  local -a \
    test_params \
    cmd
  prolog "${@}"
  prefix="${1?cannot have prefix empty}"
  version="${2?cannot have version empty}"
  pids_collector_ref="${3:-"TEST_PIDS"}"
  test_params_ref="${4:-"ANSIBLE_TEST_PARAMS"}"
  test_types_ref="${5:-"TEST_TYPES"}"
  test_params=("${test_params_ref[@]}")
  test_params+=("--python" "${version}")
  if [[ "${#test_types_ref[@]}" -eq 0 ]]; then
    log.warning "No test types to run"
    return 0
  fi
  for test_type in "${test_types_ref[@]}"; do
    cmd=()
    # shellcheck disable=SC2249
    case "${test_type}" in
    sanity)
      cmd=(ansible-test "${test_type}" "${ANSIBLE_TEST_EXCLUDES[@]}" "${test_params[@]}" --failure-ok --lint)
      ;;
    units)
      cmd=(ansible-test "${test_type}" "${test_params[@]}")
      ;;
    integration)
      cmd=(ansible-test "${test_type}" "${test_params[@]}")
      ;;
    esac
    report_file="${prefix}.${test_type}.${version}.output"
    utils.run_cmd 0 truncate -s 0 "${report_file}"
    message="[PARALLEL=${PARALLEL}] Running ${test_type} tests for ${version} and saving the output to ${report_file}"
    if [[ "${PARALLEL}" -eq 0 ]]; then
      log.info "[sequential] ${message}"
      log.debug "About to run: '${cmd[*]} > ${report_file} 2>&1 || true'"
      "${cmd[@]}" >"${report_file}" 2>&1 || true
    else
      log.info "[parallel] ${message}"
      log.debug "About to run: '(${cmd[*]} > ${report_file} 2>&1 || true) &'"
      ("${cmd[@]}" >"${report_file}" 2>&1 || true) &
      pids_collector_ref+=($!)
    fi
  done
  rc=0
  epilog "${rc}"
  return "${rc}"
}

# run the tests on a given branch
function run_tests_on_branch() {
  local \
    option \
    branch \
    remote \
    failures
  local -n \
    python_versions_ref
  option="${1?cannot continue without option}"
  branch="${2?cannot continue without branch}"
  remote="${3:-"origin"}"
  python_versions_ref="${4:-"PY_VERS"}"
  prolog "${@}"
  failures=0

  # switch to the branch
  git.switch_to_branch "${branch}" "${remote}"
  # apply patches
  git.apply_patches PRE_TEST_PATCHES
  log.info "Start running tests on ${option} branch ${branch}, this may take a while as no output is displayed..."
  for version in "${python_versions_ref[@]}"; do
    run_tests "${option}" "${version}" "TEST_PIDS" "ANSIBLE_TEST_PARAMS" "TEST_TYPES"
    rc=$?
    failures=$((failures + rc))
  done 2> >(tee -a "${option}.output" >&2 || true)
  log.info "The tests of ${option} on branch: ${branch}, completed with ${failures} failures"
  epilog "${failures}"
  return "${failures}"
}

# write the improvements of right over left to the target file
function write_improvements() {
  local \
    left \
    right \
    target \
    count \
    verdict
  left="${1?cannot continue without left}"
  right="${2?cannot continue without right}"
  target="${3?cannot continue without target}"
  prolog "${@}"
  echo "## Improvements are listed below" | tee -a "${target}"
  echo >> "${target}"
  echo '```diff' >> "${target}"
  diff -u0 "${left}" "${right}" | "${GREP}" '^+[^+]' | "${SED}" -e 's/ERROR/FIXED/' | tee -a "${target}"
  echo '```' >> "${target}"
  echo >> "${target}"
  count="$(diff -u0 "${left}" "${right}" | "${GREP}" -c '^+[^+]' || true)"
  verdict="Detected ${count} improvements"
  if [[ "${count}" -eq 0 ]]; then
    verdict="No improvements detected"
  fi
  echo >> "${target}"
  echo "> Summary: ${verdict}" | tee -a "${target}"
  log.info "> Summary: ${verdict}"
  epilog "${rc}"
  return 0
}

# write the regressions of right over left to the target file
function write_regressions() {
  local \
    left \
    right \
    target \
    count \
    verdict
  left="${1?cannot continue without left}"
  right="${2?cannot continue without right}"
  target="${3?cannot continue without target}"
  prolog "${@}"
  echo "## Regressions are listed below" | tee -a "${target}"
  echo >> "${target}"
  echo '```diff' >> "${target}"
  diff -u0 "${left}" "${right}" | "${GREP}" '^-[^-]' | tee -a "${target}"
  echo '```' >> "${target}"
  echo >> "${target}"
  count="$(diff -u0 "${left}" "${right}" | "${GREP}" -c '^-[^-]' || true)"
  verdict="Detected ${count} regressions"
  if [[ "${count}" -eq 0 ]]; then
    verdict="No regressions detected"
  fi
  echo >> "${target}"
  log.info "> Summary: ${verdict}"
  if [[ "${count}" -gt 0 ]]; then
    echo "> Action items: fix the above regressions" | tee -a "${target}"
    log.info "> Action items: fix the above regressions"
  fi
  epilog "${rc}"
  return 0
}

# generate the test report in diff format
function generate_report() {
  local \
    option \
    rc \
    target_report
    curr_errors_file
  local -a \
    options \
    output_files \
    errors_files \
    find_cmd
  target_report="${1:-"${GITHUB_STEP_SUMMARY}"}"
  shift 1
  options=("${@}")
  rc=0
  utils.run_cmd 0 truncate -s 0 "${target_report}"
  log.warning "Target report file: ${target_report} cleaned up or created."
  if [[ "${#options[@]}" -eq 0 ]]; then
    log.info "no options passed, nothing to do"
    return "${rc}"
  fi
  errors_files=()
  log.info "Collecting regression information"
  # find the output files, sort them in order of modification time
  for option in "${options[@]}"; do
    find_cmd=("${FIND}" . -type f -maxdepth 1 -name "${option}"\*.output -printf "%T@\t%p\n")
    mapfile -t output_files < <("${find_cmd[@]}" | sort -nr | cut -f2- || true)
    log.debug "Detected ${#output_files[@]} output files for ${option}"
    log.trace "Detected output files: '$(join_by "', '" "${output_files[@]}" || true)'"
    if [[ "${#output_files[@]}" -eq 0 ]]; then
      log.warning "No output files found for ${option}"
      continue
    fi
    curr_errors_file="${option}.errors"
    utils.run_cmd 0 truncate -s 0 "${curr_errors_file}"
    log.debug "Generated empty errors file: ${curr_errors_file}"
    for file in "${output_files[@]}"; do
      log.debug "Processing ${file}"
      "${GREP}" -E "((ERROR|FATAL):|FAILED )" "${file}" \
        | "${GREP}" -v "issue(s) which need to be resolved\|See error output above for details.\|Command \"ansible-doc -t module .*\" returned exit status .*\." \
        | "${SED}" -r 's/\x1B\[[0-9]{1,2}[mGK]//g' >> "${curr_errors_file}"
      log.debug "Appended to errors file: ${curr_errors_file}"
    done
    errors_files+=("${option}.errors")
  done

  # remove line numbers from the errors files
  for file in "${errors_files[@]}"; do
    "${SED}" -i -E -e 's/:[0-9]+:/:/' -e 's/:[0-9]+:/:/' "${file}" || true
    log.debug "Cleaned up line numbers from ${file}"
  done

  write_improvements "${errors_files[0]}" "${errors_files[1]}" "${target_report}"
  write_regressions "${errors_files[0]}" "${errors_files[1]}" "${target_report}"

  return "${rc}"
}


function main() {
  local \
    option \
    rc
  local -a \
    options
  local -A \
    branches_map
  options=(
    "source"
    "target"
  )
  branches_map['source']="${SOURCE_BRANCH}"
  branches_map['target']="${TARGET_BRANCH}"

  # detect the OS and setup the tools
  utils.tools_setup "$(uname -s || true)"
  utils.ensure_apps "${FIND}" "${GREP}" "${SED}" git python tr diff ansible-test
  utils.print_python_modules "ansible" "pytest"
  log.info "Branches map: '${branches_map[*]}'"
  if [[ "${PARALLEL}" -gt 0 ]]; then
    log.info "This script was launched with PARALLEL=${PARALLEL}"
  fi

  # initialize the test types
  setup_test_types TEST_TYPES "${@}"
  log.info "Accepted test types: '$(join_by "', '" "${TEST_TYPES[@]}" || true)'"
  # extract all the supported python versions from the error message, excluding 3.5
  mapfile -t PY_VERS < <(
    ansible-test sanity "${ANSIBLE_TEST_EXCLUDES[@]}" "${ANSIBLE_TEST_PARAMS[@]}" --python 1.0 --failure-ok 2>&1 |
      python -c "${PY_CODE}" | tr '[:space:]' '\n' |
      sort -V ||
      true
  )
  log.info "Detected Python versions: '$(join_by "', '" "${PY_VERS[@]}" || true)'"
  for option in "${options[@]}"; do
    log.info "Entering ${option} runs of tests on branch ${branches_map[${option}]}"
    run_tests_on_branch "${option}" "${branches_map["${option}"]}" "${REMOTE}" "PY_VERS"
    log.info "Completed ${option} runs of tests on branch ${branches_map[${option}]}"
  done

  if [[ "${PARALLEL}" -gt 0 ]]; then
    log.info "Waiting for tests running in parallel to complete..."
    wait "${TEST_PIDS[@]}"
    log.info "Tests with PIDs: [$(join_by ", " "${TEST_PIDS[@]}" || true)] have completed"
  fi
  generate_report "${GITHUB_STEP_SUMMARY}" "${options[@]}"
  rc=$?
  epilog "${rc}"
  return "${rc}"
}

if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
  log.warning "This script is not meant to be sourced"
  RC=1
else
  trap "git checkout ${CURRENT_BRANCH}" EXIT
  main "${@}"
  RC=$?
fi

exit "${RC}"
# run_ansible_test.sh ends here
