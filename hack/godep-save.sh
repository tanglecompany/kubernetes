#!/bin/bash

# Copyright 2016 The Kubernetes Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -o errexit
set -o nounset
set -o pipefail

KUBE_ROOT=$(dirname "${BASH_SOURCE}")/..
source "${KUBE_ROOT}/hack/lib/init.sh"
source "${KUBE_ROOT}/hack/lib/util.sh"

kube::util::ensure_single_dir_gopath
kube::util::ensure_godep_version v79

if [ -e "${KUBE_ROOT}/vendor" -o -e "${KUBE_ROOT}/Godeps" ]; then
  echo "The directory vendor/ or Godeps/ exists. Remove them before running godep-save.sh" 1>&2
  exit 1
fi

# Some things we want in godeps aren't code dependencies, so ./...
# won't pick them up.
REQUIRED_BINS=(
  "github.com/ugorji/go/codec/codecgen"
  "github.com/onsi/ginkgo/ginkgo"
  "github.com/jteeuwen/go-bindata/go-bindata"
  "./..."
)

pushd "${KUBE_ROOT}" > /dev/null
  # sanity check that staging directories do not exist in GOPATH
  error=0
  for repo in $(ls ${KUBE_ROOT}/staging/src/k8s.io); do
    if [ -e "${GOPATH}/src/k8s.io/${repo}" ]; then
      echo "k8s.io/${repo} exists in GOPATH. Remove before running godep-save.sh." 1>&2
      error=1
    fi
  done
  if [ "${error}" = "1" ]; then
    exit 1
  fi

  GOPATH=${GOPATH}:${KUBE_ROOT}/staging godep save "${REQUIRED_BINS[@]}"

  # create a symlink in vendor directory pointing to the staging client. This
  # let other packages use the staging client as if it were vendored.
  for repo in $(ls ${KUBE_ROOT}/staging/src/k8s.io); do
   if [ ! -e "vendor/k8s.io/${repo}" ]; then
     ln -s "../../staging/src/k8s.io/${repo}" "vendor/k8s.io/${repo}"
   fi
  done
popd > /dev/null

echo "Don't forget to run hack/update-godep-licenses.sh if you added or removed a dependency!"
