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
utils.tools_setup "$(uname -s || true)"
log.info "OS: ${OS}, FIND: ${FIND}, GREP: ${GREP}, SED: ${SED}"
# --- End of OS Detection and Tool Setup ---

# when run outside of a GitHub action (or the user has not set it to a file) throw away the output
GITHUB_STEP_SUMMARY="${GITHUB_STEP_SUMMARY:-/dev/null}"

README="${README:-"README.md"}"

# count the number of failures in this counter
failures=0

message="Missing roles in ${README}"
log.warning "${message}"
echo "# ${message}" >> "${GITHUB_STEP_SUMMARY}"
while read -r role_readme; do
  role="${role_readme%/*}"  # strip last file `/README.md`
  role="${role#*/}"         # strip left `roles/`
  role="${role/\//.}"       # replace `/` with `.`
  if ! "${GREP}" -q "^\[redhatci\.ocp\.${role}\]" "${README}"; then
    message="Missing role ${role} in ${README}"
    log.warning "${message}"
    echo "- ${message}" >> "${GITHUB_STEP_SUMMARY}"
    # increase the failures count
    failures=$((failures + 1))
  fi
done < <("${FIND}" roles -name "${README}" || true)

PY_CODE="import re, sys; [print(m.group(0)) for m in re.finditer(r'^\[redhatci\.ocp\.[^\]]+', sys.stdin.read(), re.MULTILINE)]"
message="Additional roles/plugins in ${README}"
log.warning "${message}"
echo "# ${message}" >> "${GITHUB_STEP_SUMMARY}"
while read -r role; do
  rp="${role/redhatci.ocp./}"
  if [[ ! -d "roles/${rp/./\/}" ]] &&
     [[ ! -r "plugins/filter/${rp}.py" ]] &&
     [[ ! -r "plugins/modules/${rp}.py" ]]; then
    message="Extra role/plugin found in ${README}: ${role}"
    log.warning "${message}"
    echo "- ${message}" >> "${GITHUB_STEP_SUMMARY}"
    # increase the failures count
    failures=$((failures + 1))
  fi
done < <(python -c "${PY_CODE}" < "${README}" | tr -d '[' || true)

rc=0
if [[ "${failures}" -gt 0 ]]; then
  rc=1
  log.die "${rc}" "Failure: collected ${failures} failures"
fi
log.info "Success: collected no failures"
exit "${rc}"
# check_doc.sh ends here
