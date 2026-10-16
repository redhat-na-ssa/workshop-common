#!/usr/bin/env bash
# Build a workshop site the way its Pages workflow does, and serve it locally.
#
#   ../workshop-common/scripts/preview.sh [--watch] [--local-ui] [--no-serve] [PLAYBOOK]
#
# Run it from a workshop checkout. It needs Node.js (for npx) and python3.
# The site is built into www/ from PLAYBOOK (default-site.yml) and served on
# http://localhost:8080/ (set PORT to change it) until you press Ctrl+C.
#
#   --watch      rebuild whenever a page, image or playbook changes
#   --local-ui   use this workshop-common checkout's ui/ instead of the published bundle
#   --no-serve   build once and exit
set -euo pipefail

watch=false local_ui=false serve=true playbook=default-site.yml
for arg in "$@"; do
  case "$arg" in
    --watch) watch=true ;;
    --local-ui) local_ui=true ;;
    --no-serve) serve=false ;;
    -h|--help) sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    -*) echo "Unknown option $arg" >&2; exit 1 ;;
    *) playbook=$arg ;;
  esac
done
if [ ! -f "$playbook" ]; then
  echo "No $playbook here: run this from a workshop checkout." >&2
  exit 1
fi

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
work="$(mktemp -d)"
trap 'kill $(jobs -p) 2>/dev/null || true; rm -rf "$work"' EXIT

ui_args=()
if [ "$local_ui" = true ]; then
  "$root/scripts/build-ui-bundle.sh" "$work/ui-bundle.zip"
  ui_args=(--ui-bundle-url "$work/ui-bundle.zip")
fi

# the same Antora and extension versions as .github/workflows/pages.yml
build() {
  npx --yes \
    --package @antora/cli@3.1 \
    --package @antora/site-generator@3.1 \
    --package @asciidoctor/tabs@1.0.0-beta.6 \
    antora generate "$playbook" \
    --to-dir www \
    ${ui_args[@]+"${ui_args[@]}"}
}
build

if [ "$serve" = false ]; then
  exit 0
fi
port=${PORT:-8080}
python3 -m http.server "$port" --bind 127.0.0.1 --directory www >/dev/null 2>&1 &
echo "Serving the site on http://localhost:$port/ (Ctrl+C stops it)"

if [ "$watch" = false ]; then
  wait
  exit 0
fi
echo "Watching for changes..."
touch "$work/stamp"
while sleep 2; do
  changed=$(find . -path ./www -prune -o -path ./.git -prune -o -path ./node_modules -prune \
    -o -path ./.cache -prune -o -path ./build -prune \
    -o -type f -newer "$work/stamp" -print -quit)
  if [ -n "$changed" ]; then
    touch "$work/stamp"
    echo "Rebuilding after a change to $changed"
    build || echo "The build failed; fix the error and save again."
  fi
done
