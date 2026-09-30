#!/usr/bin/env bash
#
# Fails when the branch under review contains any merge commit relative to the
# base revision. The policy lint-git documents is that a branch under review is
# rebased onto its base branch, never merged with it, so test for that directly
# rather than inferring it from the parent topology of each merge commit.
#
# Usage: no-merge-commits.sh [base-revision]
#   base-revision  defaults to refs/mcvs/base, the ref the action fetches from
#                  the base repository.
#   BASE_REF       optional; the human-readable base branch name used in output.
#
set -euo pipefail

BASE_REV="${1:-refs/mcvs/base}"
BASE_LABEL="${BASE_REF:-${BASE_REV}}"

if [ -n "$(git rev-list --merges "${BASE_REV}..HEAD")" ]; then
  echo "❗ Merge commits found on this branch. Rebase on ${BASE_LABEL}" \
       "instead of merging into it:"
  git log --format='  %h %s' --merges "${BASE_REV}..HEAD"
  exit 1
fi

echo "✅ No merge commits found"
