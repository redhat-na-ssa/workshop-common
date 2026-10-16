#!/usr/bin/env bash
# Installs this workshop's own command-line tools into its tools image, on top of the
# shared ones (oc, kubectl, helm, jq, yq, git, curl, wget, skopeo, docker shim).
# The image build runs it as root, with TARGETARCH set to amd64 or arm64.
# List each command it installs in tools/extra-tools, one per line.
set -euo pipefail

# Example:
# curl -sSL "https://example.com/tool-linux-${TARGETARCH}.tar.gz" | tar -xz -C /usr/local/bin tool
