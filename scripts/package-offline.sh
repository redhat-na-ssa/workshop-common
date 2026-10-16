#!/usr/bin/env bash
# Package a workshop's Helm chart and offline files from workshop-common's offline/.
#
#   ../workshop-common/scripts/package-offline.sh [--out DIR] [--chart-index DIR] [--docs]
#
# Run it from a workshop repo. It renders offline/chart for this workshop into
# .offline-chart/ (the tools image bundles it), lints it and packages it into --out
# (default .). --chart-index DIR also writes DIR/index.yaml and the package, a static
# Helm chart repository the site serves at /helm/. --docs also renders DISCONNECTED.md,
# TOOLS.md and tools-deployment.yaml into --out.
#
# Settings come from the environment, with defaults from the repo:
#   WORKSHOP_NAME   repo name                  (from GITHUB_REPOSITORY or the origin remote)
#   WORKSHOP_TITLE  site title                 (site.title in default-site.yml)
#   WORKSHOP_IMAGE  runtime image, no tag      (ghcr.io/<owner>/<name>)
#   RELEASE_TAG     release, such as v1.0.0    (the v* tag on HEAD, else "latest")
#   CHART_VERSION   chart version              (RELEASE_TAG without the v, else
#                                               <latest release>+g<sha> or 0.0.0+g<sha>)
set -euo pipefail

out=. index= docs=false
while [ $# -gt 0 ]; do
  case "$1" in
    --out) out=${2:?}; shift ;;
    --chart-index) index=${2:?}; shift ;;
    --docs) docs=true ;;
    -h|--help) sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Unknown option $1" >&2; exit 1 ;;
  esac
  shift
done
command -v helm >/dev/null || { echo "package-offline.sh needs helm on PATH" >&2; exit 1; }
[ -f default-site.yml ] || { echo "No default-site.yml here: run this from a workshop repo." >&2; exit 1; }

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
repo=${GITHUB_REPOSITORY:-$(git remote get-url origin 2>/dev/null | sed -e 's#\.git$##' -e 's#^git@github.com:##' -e 's#^https://github.com/##')}
owner=$(printf '%s' "${repo%%/*}" | tr '[:upper:]' '[:lower:]')
name=${WORKSHOP_NAME:-${repo##*/}}
title=${WORKSHOP_TITLE:-$(sed -n 's/^  title: *"\{0,1\}\([^"]*\)"\{0,1\} *$/\1/p' default-site.yml | head -1)}
image=${WORKSHOP_IMAGE:-ghcr.io/$owner/$name}
sha=$(git rev-parse --short HEAD)
latest=$(git describe --tags --abbrev=0 --match 'v*' 2>/dev/null || true)
exact=$(git describe --tags --exact-match --match 'v*' 2>/dev/null || true)
tag=${RELEASE_TAG:-${exact:-latest}}
if [ -n "${CHART_VERSION:-}" ]; then
  version=$CHART_VERSION
elif [[ "$tag" =~ ^v[0-9] ]]; then
  version=${tag#v}
elif [ -n "$latest" ]; then
  version="${latest#v}+g$sha"  # ahead of the latest release
else
  version="0.0.0+g$sha"
fi

esc() { printf '%s' "$1" | sed 's/[\\|&]/\\&/g'; }
render() {
  sed -e "s|@@NAME@@|$(esc "$name")|g" \
      -e "s|@@TITLE@@|$(esc "$title")|g" \
      -e "s|@@IMAGE@@|$(esc "$image")|g" \
      -e "s|@@TAG@@|$(esc "$tag")|g" \
      -e "s|@@VERSION@@|$(esc "$version")|g" "$1"
}

rm -rf .offline-chart
mkdir -p .offline-chart/templates "$out"
for f in Chart.yaml values.yaml; do render "$root/offline/chart/$f" > ".offline-chart/$f"; done
for f in "$root"/offline/chart/templates/*; do render "$f" > ".offline-chart/templates/$(basename "$f")"; done

echo "Packaging chart $name $version (app $tag, image $image)"
helm lint .offline-chart
helm package .offline-chart --version "$version" --app-version "$tag" --destination "$out"

if [ -n "$index" ]; then
  mkdir -p "$index"
  rm -f "$index"/*.tgz "$index/index.yaml"
  cp "$out/$name-$version.tgz" "$index/"
  # relative chart URLs, so the repository works at any address
  helm repo index "$index"
fi

if [ "$docs" = true ]; then
  for f in DISCONNECTED.md TOOLS.md tools-deployment.yaml; do render "$root/offline/$f" > "$out/$f"; done
fi
