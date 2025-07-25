#!/usr/bin/env bash
#
# Copyright (C) 2023 Red Hat, Inc.
#
# Author: Jorge A Gallegos <jgallego@redhat.com>
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
#
#~Usage:
#~  ansible-lint.sh [-b BIN] [-d] [PATH]
#~
#~Options:
#~  -b BIN  Path to the `ansible-lint` binary (default: $PATH/ansible-lint)
#~  -d      Download requirements declared in galaxy.yml (default: False)
#~Arguments:
#~  PATH    (Optional) path to lint, defaults to the top level directory

TOPDIR="$(git rev-parse --show-toplevel || true)"
test -z "${TOPDIR}" && { echo "FATAL: This script expects to run from a specific git repository" >&2; exit 1; }
# shellcheck source=hack/common_lib.bash
source "${TOPDIR}/hack/common_lib.bash"

utils.tools_setup "$(uname -s || true)"

function usage(){
    grep "^#~" "$0" | sed -e "s/#~//" || true
}

function installation_instructions() {
    echo "You need to install ansible-lint. Ideally from the source code branch"
    echo "Example:"
    echo -e "pip install 'ansible-lint[lock] @ git+https://github.com/ansible/ansible-lint@v6'"
}

if [[ "${SCRIPT_DEBUG}" -gt 1 ]]; then
    set -x
fi

BIN="$(command -v ansible-lint || true)"
OFFLINE="--offline"
declare -a EXTRA_ARGS
EXTRA_ARGS+=(
    --force-color
    --parseable
)

while getopts ":b:d" option; do
    case "${option}" in
        b)
            BIN="${OPTARG}"
            shift 2
            ;;
        d)
            OFFLINE=""
            shift 1
            ;;
        *)
            usage
            log.die 1 "Invalid option: ${option}"
            ;;
    esac
done

BIN="$(command -v "${BIN}" || true)"
declare -a CMD

if ! [[ -x "${BIN}" ]]; then
    installation_instructions
    log.die 1 "Cannot find passed or detected ansible-lint binary: ${BIN}"
fi
CMD=("${BIN}")
if [[ -n "${OFFLINE}" ]]; then
    CMD+=("${OFFLINE}")
fi
CMD+=("${EXTRA_ARGS[@]}")
if [[ "${#@}" -gt 0 ]]; then
    CMD+=("${@}")
fi

pushd "${PWD}" >/dev/null 2>&1 || true
cd "${TOPDIR}" >/dev/null 2>&1 || true
log.info "Running: ${CMD[*]}"
"${CMD[@]}" && RC=$? || RC=$?
popd >/dev/null 2>&1 || true

exit "${RC}"
