# Sourced from ~/.bashrc in interactive shells (such as oc exec -it ... bash).
# shellcheck shell=bash
[[ $- == *i* ]] || return 0
[[ -n ${_WORKSHOP_TOOLS_BANNER_DONE-} ]] && return 0
export _WORKSHOP_TOOLS_BANNER_DONE=1

tools=()
for t in oc kubectl helm jq yq curl wget git gpg skopeo docker $(sed 's/#.*//' /usr/local/share/workshop/extra-tools 2>/dev/null); do
  command -v "$t" >/dev/null 2>&1 && tools+=("$t")
done
printf '\n%s command-line tools:\n  %s\n' "${WORKSHOP_TITLE:-Workshop}" "${tools[*]}"
printf '%s\n' "  docker is a client shim (no engine): manifest inspect, pull, image inspect, history"
printf '%s\n\n' "The workshop's Helm chart is in ~/chart; install it with --set tools.enabled=false from here."
