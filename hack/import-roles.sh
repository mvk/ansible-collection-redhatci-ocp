#!/usr/bin/env bash
#
# Copyright (C) 2021-2023 Red Hat, Inc.
#
# Author: Frederic Lepied <flepied@redhat.com>
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
#~  import-roles <INPUT>
#~
#~Arguments:
#~  INPUT       File with a list of repositories to import from, the format of
#~              the file is "URL BRANCH PATH(S)"



TOPDIR="$(git rev-parse --show-toplevel || true)"
test -z "${TOPDIR}" && { echo "FATAL: This script expects to run from a specific git repository" >&2; exit 1; }
# shellcheck source=hack/common_lib.bash
source "${TOPDIR}/hack/common_lib.bash"

utils.tools_setup "$(uname -s || true)"

function usage(){
    "${GREP}" '^#~' "$0" | sed -e 's/#~//' || true
}

INPUT="$1"

if [[ -z "${INPUT}" ]]
then
    usage
    exit 1
fi

INPUT="$( readlink -f "${INPUT}" )"

if [[ ! -f "${INPUT}" ]]
then
    echo "File ${INPUT} does not exist"
    exit 2
fi

# Check we have git-filter-repo installed
if ! git filter-repo -h &>/dev/null; then
    echo "The git-filter-repo subcommand is needed, please install first"
    exit 3
fi

set -ex
TEMPDIR="$( mktemp -d )"
mkdir -pv "${TEMPDIR}/mixin"
git -C "${TEMPDIR}/mixin" init
TOPDIR="$(git rev-parse --show-toplevel)"
CWD="${PWD}"

cd "${TEMPDIR}"
# This leaves us with a repo with a single roles/ directory
while read -r url branch paths; do
    repo="$( basename "${url}" .git )"

    # fresh clone
    git clone "${url}"
    cd "${repo}"

    PATHS=
    for path in ${paths}; do
        PATHS="${PATHS} --path=${path} --path-rename=${path}:roles"
    done

    # leave the repo in a "clean" state only with a roles/ subdir
    git filter-repo "${PATHS}"

    # mix all commits in the mixin repo
    git -C "${TEMPDIR}/mixin" remote add "${repo}" "${TEMPDIR}"/"${repo}"
    git -C "${TEMPDIR}/mixin" fetch "${repo}" "${branch}"
    # by merging and not rebasing we keep the history consistent
    git -C "${TEMPDIR}/mixin" merge --allow-unrelated-histories "${repo}"/"${branch}"

    cd ..
done <<< "${INPUT}"

cd "${TOPDIR}"

git branch -D import-workspace || echo "no import workspace found"
git remote rm mixin || echo "no remote mixin found"
git switch --orphan import-workspace
git merge main
git remote add mixin "${TEMPDIR}"/mixin
git fetch mixin
git merge --allow-unrelated-histories mixin/main

git gc

cd "${CWD}"
