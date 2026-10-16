#!/usr/bin/env bash
# Start a new workshop repo from template/.
#
#   scripts/new-workshop.sh DIR "Site title" [NAME "First workshop title"]
#
# DIR's name becomes the repo name, such as ../openshift-201-workshop. The repo starts
# with the home part (content/) and one workshop, workshops/NAME (first-steps unless
# given); add more with add-workshop.py. The owner is the one this workshop-common
# checkout came from (set OWNER to override), so the repo loads the same shared look
# and workflows as the others.
set -euo pipefail

if [ $# -ne 2 ] && [ $# -ne 4 ]; then
  sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'
  exit 1
fi
dir=$1
title=$2
first=${3:-first-steps}
first_title=${4:-First Steps}
repo=$(basename "$dir")

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [ -z "${OWNER:-}" ]; then
  remote=$(git -C "$root" remote get-url origin)
  remote=${remote%.git}
  remote=${remote#git@github.com:}
  remote=${remote#https://github.com/}
  OWNER=${remote%%/*}
fi

if [ -e "$dir" ] && [ -n "$(ls -A "$dir")" ]; then
  echo "$dir already exists and isn't empty." >&2
  exit 1
fi
mkdir -p "$dir"
cp -R "$root/template/." "$dir/"

# escape the values for sed: backslash, the | delimiter and &
esc() { printf '%s' "$1" | sed 's/[\\|&]/\\&/g'; }
grep -rl '@@' "$dir" | while read -r f; do
  sed -i.bak \
    -e "s|@@TITLE@@|$(esc "$title")|g" \
    -e "s|@@REPO@@|$(esc "$repo")|g" \
    -e "s|@@OWNER@@|$(esc "$OWNER")|g" \
    "$f"
  rm -f "$f.bak"
done

(cd "$dir" && "$root/scripts/add-workshop.py" "$first" "$first_title" >/dev/null)

git -C "$dir" init --quiet --initial-branch main
git -C "$dir" add --all
git -C "$dir" commit --quiet --message "Start $title from the workshop-common template"

cat <<NEXT
Created $dir for $OWNER/$repo.
Next: follow "Adding a workshop" in $root/README.adoc,
starting with creating $OWNER/$repo on GitHub and pushing main.
NEXT
