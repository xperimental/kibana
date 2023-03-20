#!/usr/bin/env bash
#
# Duplicates the yarn registry setting from the npm configuration.

set -e -u -o pipefail

registry=$(npm config get registry)
readonly registry

yarn config set registry "${registry}"
