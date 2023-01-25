#!/usr/bin/env bash

set -e -u -o pipefail

target_dir=$1

mkdir -p "$target_dir"
ln -s /usr/bin/node "$target_dir/node"
