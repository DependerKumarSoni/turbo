#!/bin/bash

# This script is called from within a prysk test, so pwd is already in the prysk tmp directory.

set -eo pipefail

exampleName=$1
pkgManager=$2
pkgManagerWithVersion=$3

# Copy the example dir over to the test dir that prysk puts you in
SCRIPT_DIR=$(dirname "${BASH_SOURCE[0]}")
MONOREPO_ROOT_DIR="$SCRIPT_DIR/../.."
TURBOREPO_TESTS_DIR="$SCRIPT_DIR/.."
EXAMPLE_DIR="$MONOREPO_ROOT_DIR/examples/$exampleName"

TARGET_DIR="$(pwd)"

cp -a "$EXAMPLE_DIR/." "${TARGET_DIR}/"

# cleanup lockfiles so we can install from scratch
[ ! -f yarn.lock ] || mv yarn.lock yarn.lock.bak
[ ! -f pnpm-lock.yaml ] || mv pnpm-lock.yaml pnpm-lock.yaml.bak
[ ! -f package-lock.json ] || mv package-lock.json package-lock.json.bak


TURBO_VERSION_FILE="${MONOREPO_ROOT_DIR}/version.txt"
# Change package.json in the example directory to point to @canary if our branch is currently at that version
TURBO_TAG=$(cat "$TURBO_VERSION_FILE" | sed -n '2 p')
if [ "$TURBO_TAG" == "canary" ]; then
  jq --arg version "canary" '.devDependencies.turbo = $version' package.json > package.json.new
  mv package.json.new package.json
fi

# Delete .git directory if it's there, we'll set up a new git repo
[ ! -d .git ] || rm -rf .git
"${TURBOREPO_TESTS_DIR}/helpers/setup_git.sh" "${TARGET_DIR}"
"${TURBOREPO_TESTS_DIR}/helpers/setup_package_manager.sh" "${TARGET_DIR}" "$pkgManagerWithVersion"

# Enable corepack so that when we set the packageManager in package.json it actually makes a diference.
if [ "$PRYSK_TEMP" == "" ]; then
  COREPACK_INSTALL_DIR_CMD=
else
  COREPACK_INSTALL_DIR="${PRYSK_TEMP}/corepack"
  mkdir -p "${COREPACK_INSTALL_DIR}"
  export PATH=${COREPACK_INSTALL_DIR}:$PATH
  COREPACK_INSTALL_DIR_CMD="--install-directory=${COREPACK_INSTALL_DIR}"
fi
corepack enable "${COREPACK_INSTALL_DIR_CMD}"
"${TURBOREPO_TESTS_DIR}/helpers/install_deps.sh" "$pkgManager"

if [ "${OSTYPE}" == "msys" ]; then
  EXT=".exe"
else
  EXT=""
fi
export TURBO_BINARY_PATH=${MONOREPO_ROOT_DIR}/target/debug/turbo${EXT}
