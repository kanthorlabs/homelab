#!/usr/bin/env bash
set -e

GITHUB_TOKEN=$GITHUB_TOKEN
GITHUB_USER=${GITHUB_USER:-"kanthorlabs"}
GITHUB_REPO=${GITHUB_REPO:-"homelab"}
GITHUB_BRANCH=${GITHUB_BRANCH:-"main"}
CLUSTER_PATH=${CLUSTER_PATH:-"clusters/cantholabs"}

if [[ -z "$GITHUB_TOKEN" ]]; then
    echo "❌ ERROR: GITHUB_TOKEN is required but not set!"
    echo "Please set it using: export GITHUB_TOKEN='github_pat_xxx'"
    exit 1
fi

flux bootstrap github \
  --components-extra=image-reflector-controller,image-automation-controller \
  --owner=$GITHUB_USER \
  --repository=$GITHUB_REPO \
  --branch=$GITHUB_BRANCH \
  --path=$CLUSTER_PATH \
  --read-write-key \
  --reconcile \
  --personal