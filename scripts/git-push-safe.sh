#!/usr/bin/env bash
set -euo pipefail

if ! git remote >/dev/null 2>&1; then
  echo "No git remotes configured. Add one with: git remote add origin <url>" >&2
  exit 1
fi

if [ -z "$(git remote)" ]; then
  echo "No git remotes configured. Add one with: git remote add origin <url>" >&2
  exit 1
fi

git push "$@"
