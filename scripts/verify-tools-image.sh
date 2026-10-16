#!/usr/bin/env bash
# Check a workshop tools image: every shared tool and the bundled chart work, and every
# tool listed in the workshop's tools/extra-tools is on PATH. Then, if the workshop has
# tools/verify.sh, run it inside the image too.
#
#   ../workshop-common/scripts/verify-tools-image.sh IMAGE:TAG
#
# Run it from the workshop repo, with podman or docker.
set -euo pipefail
img=${1:?usage: verify-tools-image.sh IMAGE:TAG}
engine=$(command -v podman || command -v docker)

"$engine" run --rm --entrypoint bash "$img" -c '
  set -euo pipefail
  oc version --client | head -n 1
  kubectl version --client=true | head -n 1
  helm version --short
  jq --version
  yq --version
  git --version
  curl --version | head -n 1
  wget --version | head -n 1
  skopeo --version
  test -x /usr/local/bin/docker
  for t in $(sed "s/#.*//" /usr/local/share/workshop/extra-tools 2>/dev/null); do
    command -v "$t" >/dev/null || { echo "missing tool: $t" >&2; exit 1; }
    echo "found $t"
  done
  helm template check /workshop/chart >/dev/null
  echo "chart renders"
'
if [ -f tools/verify.sh ]; then
  "$engine" run --rm --interactive --entrypoint bash "$img" -s < tools/verify.sh
fi
echo "Tools image $img is good."
