#!/usr/bin/env bash
# Commits as '<type>(<branch>): <message>' in whichever git repo the caller's
# cwd belongs to — the parent repo, or a submodule (akpedia-server, akpedia-ml,
# akpedia-client) if run from inside one — scoping to its current AKP-<number> branch.
set -uo pipefail

commit_types="feat fix docs style refactor perf test chore build ci revert"

usage() {
  echo "usage: akpedia commit <type> <message>" >&2
  echo "types: $commit_types" >&2
}

repo="$(git rev-parse --show-toplevel 2>/dev/null)"
if [ -z "$repo" ]; then
  echo "not inside a git repository" >&2
  exit 1
fi

type="${1:-}"
[ $# -gt 0 ] && shift
message="$*"

if [[ ! " $commit_types " == *" $type "* ]]; then
  usage
  exit 1
fi

if [ -z "$message" ]; then
  usage
  exit 1
fi

branch_name="$(git rev-parse --abbrev-ref HEAD)"
if [[ ! "$branch_name" =~ ^AKP-[0-9]+$ ]]; then
  echo "current branch '$branch_name' is not an AKP-<number> branch; use 'akpedia branch <number>' first" >&2
  exit 1
fi

echo "repo: $repo" >&2
git commit -m "$type($branch_name): $message"
