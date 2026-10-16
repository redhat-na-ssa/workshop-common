#!/usr/bin/env bash
# Build the workshop UI bundle: the Red Hat Showroom theme with ui/ laid over it.
#
#   scripts/build-ui-bundle.sh [output.zip]
#
# Writes build/ui-bundle.zip by default. To try a change on a workshop before
# publishing it, build the bundle and point Antora at the zip:
#
#   antora generate default-site.yml \
#     --ui-bundle-url /path/to/workshop-common/build/ui-bundle.zip
set -euo pipefail

# The theme release the overlay was written against; bump it here when moving
# to a newer theme, then check the partials in ui/partials still fit it.
BASE_URL="${BASE_URL:-https://github.com/rhpds/rhdp_showroom_theme/releases/download/v0.0.1/ui-bundle.zip}"

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
out="${1:-$root/build/ui-bundle.zip}"
case "$out" in /*) ;; *) out="$PWD/$out" ;; esac

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

curl --fail --silent --show-error --location \
  --output "$work/base.zip" \
  "$BASE_URL"
mkdir "$work/bundle"
unzip -q "$work/base.zip" -d "$work/bundle"
cp -R "$root/ui/." "$work/bundle/"

# The theme's header logo links to demo.redhat.com, which only Red Hat employees can open;
# point it at the workshop's start page, as the site title next to it already does.
sed -i.bak \
  's#href="https://demo.redhat.com" target="_blank"#href="{{{or site.url (or siteRootUrl siteRootPath)}}}"#' \
  "$work/bundle/partials/header-content.hbs"
rm "$work/bundle/partials/header-content.hbs.bak"
if grep -q 'demo.redhat.com' "$work/bundle/partials/"*.hbs; then
  echo "A partial still links to demo.redhat.com; check the theme version" >&2
  exit 1
fi

# Stamp the bundle with the workshop-common version it was built from, so each site's
# footer shows it next to the workshop's own release (ui/partials/build-info.hbs).
# The commit link points at this repo: GitHub Actions names it, otherwise the origin remote does.
if [ -z "${REPO_URL:-}" ] && [ -n "${GITHUB_REPOSITORY:-}" ]; then
  REPO_URL="${GITHUB_SERVER_URL:-https://github.com}/$GITHUB_REPOSITORY"
fi
if [ -z "${REPO_URL:-}" ]; then
  REPO_URL=$(git -C "$root" remote get-url origin 2>/dev/null | sed -e 's#^git@github.com:#https://github.com/#' -e 's#\.git$##' || true)
fi
common=""
if commit=$(git -C "$root" rev-parse HEAD 2>/dev/null); then
  short=$(git -C "$root" rev-parse --short=7 HEAD)
  label="<code>$short</code>"
  if release=$(git -C "$root" describe --tags --abbrev=0 --match 'v*' 2>/dev/null); then
    ahead=$(git -C "$root" rev-list --count "$release..HEAD")
    label="$release"
    if [ "$ahead" -eq 1 ]; then label="$release + 1 commit"; fi
    if [ "$ahead" -gt 1 ]; then label="$release + $ahead commits"; fi
  fi
  if [ -n "$(git -C "$root" status --porcelain -- ui scripts)" ]; then
    label="$label, local changes"
  fi
  common="<span>Shared setup $label</span>"
  if [ -n "${REPO_URL:-}" ]; then
    common="<span>Shared setup <a href=\"$REPO_URL/commit/$commit\">$label</a></span>"
  fi
  common="$common
<span class=\"build-info-sep\" aria-hidden=\"true\">·</span>"
fi
printf '%s\n' "$common" > "$work/bundle/partials/common-info.hbs"

mkdir -p "$(dirname "$out")"
rm -f "$out"
(cd "$work/bundle" && zip -q -r -X "$out" .)
echo "Wrote $out"
