#!/usr/bin/env bash
# Creates (if needed) and checks out AKP-<number> in whichever git repo the
# caller's cwd belongs to — the parent repo, or a submodule (akpedia-server,
# akpedia-ml, akpedia-client) if run from inside one.
set -uo pipefail

repo="$(git rev-parse --show-toplevel 2>/dev/null)"
if [ -z "$repo" ]; then
  echo "not inside a git repository" >&2
  exit 1
fi

number="${1:-}"
if [[ ! "$number" =~ ^[0-9]+$ ]]; then
  echo "usage: akpedia branch <number>" >&2
  exit 1
fi

branch_name="AKP-$number"
echo "repo: $repo" >&2
if git rev-parse --verify --quiet "$branch_name" >/dev/null; then
  git checkout "$branch_name"
else
  git checkout -b "$branch_name"
fi
