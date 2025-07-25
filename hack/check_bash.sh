#!/usr/bin/env bash

# tests bash scripts

TOP_DIR="$(git rev-parse --show-toplevel)"
HACK_DIR="${TOP_DIR}/hack"

source "${HACK_DIR}/common_lib.bash"

declare -a SCRIPTS_DIRS
SCRIPTS_DIRS+=("${HACK_DIR}")
declare -a TESTS_DIRS
TESTS_DIRS+=("test")
REPORTS_DIR="${REPORTS_DIR:-"${TOP_DIR}/reports"}"
###### TESTING SETTINGS ######
TEST_TOOL="${TEST_TOOL:-"bats"}"
declare -a TEST_PARAMS
TEST_PARAMS+=(
    "--recursive"
    "--report-formatter" "junit"
    "--output" "${REPORTS_DIR}"
)
###### LINTING SETTINGS ######
LINT_TOOL="${LINT_TOOL:-"shellcheck"}"
declare -a LINT_PARAMS
LINT_PARAMS+=(
    "-o" "all"
    "-x"
    "-f" "diff"
)

mkdir -p "${REPORTS_DIR}"

failures=0

log.info "Run tests using ${TEST_TOOL}"
log.debug "SCRIPTS_DIRS: ['$(join_by "', '" "${SCRIPTS_DIRS[@]}" || true )'] (tests under: ['$(join_by "', '" "${TESTS_DIRS[@]}" || true)'])"
for scripts_dir in "${SCRIPTS_DIRS[@]}"; do
  pushd "${PWD}" >/dev/null 2>&1 || log.die $? "Failed during 'pushd ${PWD}'"
  cd "${scripts_dir}" >/dev/null 2>&1 || log.die $? "Failed during 'cd ${scripts_dir}'"
  log.info "==> in ${scripts_dir}"
  passed=0
  failed=0
  total=0
  for test_dir in "${TESTS_DIRS[@]}"; do
    log.info "====> running tests under: ${test_dir}"
    LIVE_FOREVER=1
    utils.run_cmd 0 "${TEST_TOOL}" "${TEST_PARAMS[@]}" "${test_dir}" && rc=$? || rc=$?
    LIVE_FOREVER=0
    if [[ "${rc}" -eq 0 ]]; then
      log.info "<==== Successfully completed the tests of ${test_dir}"
      passed=$((passed + 1))
    else
      log.error "<==== Failure during '${TEST_TOOL}' of ${test_dir} with exit code ${rc}"
      failed=$((failed + 1))
      failures=$((failures + 1))
    fi
  done
  total=$((passed + failed))
  log.info "<== Tests run of folder ${scripts_dir} completed: passed: ${passed}, failed: ${failed}, total: ${total}"
  popd >/dev/null 2>&1 || log.die 1 "Failed during 'popd' with exit code ${?}"
done

log.info "Run linter using ${LINT_TOOL}"
for scripts_dir in "${SCRIPTS_DIRS[@]}"; do
  pushd "${PWD}" >/dev/null 2>&1 || log.die $? "Failed during 'pushd ${PWD}'"
  cd "${scripts_dir}" >/dev/null 2>&1 || log.die $? "Failed during 'cd ${scripts_dir}'"
  log.info "==> in ${scripts_dir}"
  rel_path_fixed="${PWD#"${TOP_DIR}/"}"
  rel_path_fixed="${rel_path_fixed//\//.}"
  passed=0
  failed=0
  total=0
  while read -r filename; do
    log.info "==> linting ${filename}"
    report_file="${filename}.patch"
    report_file="${report_file//\.\//}" # remove the leading './'
    report_file="${report_file//\//-}"  # replace '/' with '-'
    report_file="${REPORTS_DIR}/shellcheck-${rel_path_fixed}.${report_file}"
    log.debug "Generated report file name: '${report_file}'"
    LIVE_FOREVER=1
    utils.run_cmd 0 "${LINT_TOOL}" "${LINT_PARAMS[@]}" "${filename}" > "${report_file}" && rc=$? || rc=$?
    LIVE_FOREVER=0
    if [[ "${rc}" -eq 0 ]]; then
      log.info "<== Successfully completed the linting of ${filename}"
      passed=$((passed + 1))
    else
      log.error "<== Failure during '${LINT_TOOL}' of ${filename} with exit code ${rc}"
      failed=$((failed + 1))
      failures=$((failures + 1))
    fi
  done < <(find . -type f -name "*.sh" -or -name "*.bash" || true)
  total=$((passed + failed))
  log.info "<== Linting run of folder ${scripts_dir} completed: passed: ${passed}, failed: ${failed}, total: ${total}"
  popd >/dev/null 2>&1 || log.die 1 "Failed during 'popd' with exit code ${?}"
done

log.info "Total failures: ${failures}. Exiting with exit code ${failures}"
exit "${failures}"
