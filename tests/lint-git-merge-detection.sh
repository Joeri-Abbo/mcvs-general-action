#!/usr/bin/env bash
#
# Regression test for scripts/no-merge-commits.sh.
#
# Case 2 is the bypass this test exists for. The previous implementation
# inspected only ^1 and ^2 of each merge commit and failed only when exactly
# one parent was an ancestor of the base ref. A merge of a topic branch that
# was itself started from the current base tip has two parents that are both
# descendants of that tip, so it hit the `else ... continue` arm and the check
# printed a green tick. Case 2 passes against that implementation and must
# fail here.
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECK="${SCRIPT_DIR}/../scripts/no-merge-commits.sh"

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

failures=0

git_quiet() { git -c user.name=t -c user.email=t@t -c commit.gpgsign=false "$@" >/dev/null 2>&1; }

# Builds a repository whose `main` is the base branch and whose `feature`
# branch is the branch under review, then records main's tip as
# refs/mcvs/base the same way the action does.
new_repo() {
  local dir="${WORK}/$1"
  mkdir -p "${dir}"
  git_quiet -C "${dir}" init -b main
  echo base > "${dir}/base.txt"
  git_quiet -C "${dir}" add -A
  git_quiet -C "${dir}" commit -m "chore: initial commit"
  echo more >> "${dir}/base.txt"
  git_quiet -C "${dir}" add -A
  git_quiet -C "${dir}" commit -m "chore: second base commit"
  git_quiet -C "${dir}" update-ref refs/mcvs/base main
  git_quiet -C "${dir}" checkout -b feature
  echo feature > "${dir}/feature.txt"
  git_quiet -C "${dir}" add -A
  git_quiet -C "${dir}" commit -m "feat: work on the feature branch"
  echo "${dir}"
}

# Runs the check in $1 and asserts its exit status.
expect() {
  local dir="$1" want="$2" label="$3" out status
  set +e
  out="$(cd "${dir}" && BASE_REF=main "${CHECK}" refs/mcvs/base 2>&1)"
  status=$?
  set -e
  if [ "${status}" -eq "${want}" ]; then
    echo "PASS  ${label} (exit ${status})"
  else
    echo "FAIL  ${label}: expected exit ${want}, got ${status}"
    echo "${out}" | sed 's/^/      /'
    failures=$((failures + 1))
  fi
}

# ---------------------------------------------------------------------------
# Case 1 (control) — a plain merge of the base branch into the feature branch.
# The previous implementation did catch this one.
# ---------------------------------------------------------------------------
d="$(new_repo case1-merge-base-in)"
git_quiet -C "${d}" checkout main
echo drift >> "${d}/base.txt"
git_quiet -C "${d}" add -A
git_quiet -C "${d}" commit -m "chore: base moves on"
git_quiet -C "${d}" update-ref refs/mcvs/base main
git_quiet -C "${d}" checkout feature
git_quiet -C "${d}" merge --no-ff -m "Merge branch 'main' into feature" main
expect "${d}" 1 "merge of the base branch into the feature branch is rejected"

# ---------------------------------------------------------------------------
# Case 2 (the bypass) — merge a topic branch that was itself started from the
# current base tip. Both parents are descendants of refs/mcvs/base, so the
# previous parent-shape heuristic skipped the commit and exited 0.
# ---------------------------------------------------------------------------
d="$(new_repo case2-bypass)"
git_quiet -C "${d}" checkout -b topic refs/mcvs/base
echo topic > "${d}/topic.txt"
git_quiet -C "${d}" add -A
git_quiet -C "${d}" commit -m "feat: topic branch work"
git_quiet -C "${d}" checkout feature
git_quiet -C "${d}" merge --no-ff -m "Merge branch 'topic' into feature" topic
expect "${d}" 1 "merge whose parents are both off the base tip is rejected"

# ---------------------------------------------------------------------------
# Case 3 — an octopus merge.
# ---------------------------------------------------------------------------
d="$(new_repo case3-octopus)"
for n in a b; do
  git_quiet -C "${d}" checkout -b "topic-${n}" refs/mcvs/base
  echo "${n}" > "${d}/topic-${n}.txt"
  git_quiet -C "${d}" add -A
  git_quiet -C "${d}" commit -m "feat: topic ${n}"
done
git_quiet -C "${d}" checkout feature
git_quiet -C "${d}" merge --no-ff -m "Merge topics" topic-a topic-b
expect "${d}" 1 "octopus merge is rejected"

# ---------------------------------------------------------------------------
# Case 4 — a linear, rebased branch must still pass. Guards against a fix that
# simply fails everything.
# ---------------------------------------------------------------------------
d="$(new_repo case4-linear)"
echo second >> "${d}/feature.txt"
git_quiet -C "${d}" add -A
git_quiet -C "${d}" commit -m "feat: a second feature commit"
expect "${d}" 0 "linear branch is accepted"

# ---------------------------------------------------------------------------
# Case 5 — a merge commit that is already contained in the base branch must not
# be attributed to the branch under review.
# ---------------------------------------------------------------------------
d="$(new_repo case5-merge-in-base)"
git_quiet -C "${d}" checkout -b base-topic refs/mcvs/base
echo x > "${d}/x.txt"
git_quiet -C "${d}" add -A
git_quiet -C "${d}" commit -m "feat: work merged into the base branch"
git_quiet -C "${d}" checkout main
git_quiet -C "${d}" merge --no-ff -m "Merge branch 'base-topic'" base-topic
git_quiet -C "${d}" update-ref refs/mcvs/base main
git_quiet -C "${d}" checkout feature
git_quiet -C "${d}" rebase refs/mcvs/base
expect "${d}" 0 "a merge already in the base branch is not attributed here"

echo
if [ "${failures}" -ne 0 ]; then
  echo "${failures} case(s) failed"
  exit 1
fi
echo "all cases passed"
