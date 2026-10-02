# Add directories to the PATH unless already present
add_to_path() {
  if [[ -d "$1" ]] && [[ ":$PATH:" != *":$1:"* ]]; then
    export PATH="$1:$PATH"
  fi
}

# Get the argo password
argo_passwd() {
  kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d
}

# Easy way to login for AWS. On Linux aws-sso keeps its secrets in a
# password-protected file keyring; set AWS_PWD (e.g. in ~/.zshrc.local) to
# answer its password prompts.
aws_plz() {
  if [[ -n "$AWS_PWD" && -z "$AWS_SSO_FILE_PASSWORD" ]]; then
    local -x AWS_SSO_FILE_PASSWORD="$AWS_PWD"
  fi
  aws-sso login || return

  # Pick a profile by account alias and role; the profile name is the first
  # CSV field.
  local profile
  profile="$(aws-sso list --csv Profile AccountAlias RoleName \
    | fzf --delimiter=, --with-nth=2.. --prompt='AWS profile> ' \
    | cut -d, -f1)"
  [[ -n "$profile" ]] || return 1
  aws-sso-profile "$profile"
}

# Show GPU allocation and GPU-requesting pods per node
kgg() {
  local node_data pod_data
  node_data=$(kubectl get nodes -o json | jq -r '
    .items[]
    | select(.status.allocatable["nvidia.com/gpu"] // .status.allocatable["amd.com/gpu"] // empty)
    | [.metadata.name,
       (.status.allocatable["nvidia.com/gpu"] // .status.allocatable["amd.com/gpu"] // "0")]
    | @tsv
  ')
  pod_data=$(kubectl get pods --all-namespaces -o json | jq -r '
    .items[]
    | select(.spec.containers[].resources.requests["nvidia.com/gpu"] // .spec.containers[].resources.requests["amd.com/gpu"] // empty)
    | [.spec.nodeName, .metadata.namespace, .metadata.name,
       ([.spec.containers[].resources.requests["nvidia.com/gpu"] // .spec.containers[].resources.requests["amd.com/gpu"] // "0"] | add)]
    | @tsv
  ' | sort)
  awk -F'\t' '
    function trunc(s, n) { return length(s) > n ? substr(s, 1, n-3) "..." : s }
    NR == FNR {
      if ($1 == "") next
      nodes[$1] = $2 + 0
      node_order[++node_count] = $1
      node_used[$1] = 0
      next
    }
    {
      if ($1 == "") next
      node_used[$1] += $4 + 0
      pod_lines[$1] = pod_lines[$1] sprintf("  %-18s  %-52s  %s\n", trunc($2, 18), trunc($3, 52), $4)
    }
    END {
      for (i = 1; i <= node_count; i++) {
        n = node_order[i]
        alloc = nodes[n]
        used = node_used[n]
        free = alloc - used
        printf "NODE: %s  (Allocatable: %d  Requested: %d  Free: %d)\n", n, alloc, used, free
        printf "  %-18s  %-52s  %s\n", "NAMESPACE", "POD", "GPUs"
        printf "  %-18s  %-52s  %s\n", "---------", "---", "----"
        if (pod_lines[n] != "") {
          printf "%s", pod_lines[n]
        } else {
          printf "  (no GPU pods)\n"
        }
        print ""
      }
    }
  ' <(echo "$node_data") <(echo "$pod_data")
}

# Install krew
# https://krew.sigs.k8s.io/docs/user-guide/setup/install/
install_krew() {
  (
    set -x; cd "$(mktemp -d)" &&
    OS="$(uname | tr '[:upper:]' '[:lower:]')" &&
    ARCH="$(uname -m | sed -e 's/x86_64/amd64/' -e 's/\(arm\)\(64\)\?.*/\1\2/' -e 's/aarch64$/arm64/')" &&
    KREW="krew-${OS}_${ARCH}" &&
    curl -fsSLO "https://github.com/kubernetes-sigs/krew/releases/latest/download/${KREW}.tar.gz" &&
    tar zxvf "${KREW}.tar.gz" &&
    ./"${KREW}" install krew
  )
}
