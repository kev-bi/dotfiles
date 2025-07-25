# Add directories to the PATH unless already present
add_to_path() {
  if [[ -d "$1" ]] && [[ ":$PATH:" != *":$1:"* ]]; then
    export PATH="$1:$PATH"
  fi
}

# Function wrapping the dotfiles custom dir copy over commands
cp_zsh_custom() {
  cp $DOTFILES/oh-my-zsh/custom/*(.) $HOME/.oh-my-zsh/custom
  if [[ -d $DOTFILES/oh-my-zsh/custom/plugins ]]; then
    files=("$DOTFILES/oh-my-zsh/custom/plugins"/*(ND))
    if [[ ${#files[@]} -gt 0 ]]; then
      cp -r $DOTFILES/oh-my-zsh/custom/plugins/* ${ZSH_CUSTOM:-${ZSH:-~/.oh-my-zsh}/custom/plugins}
    fi
  fi
  if [[ -d $DOTFILES/oh-my-zsh/custom/themes ]]; then
    files=("$DOTFILES/oh-my-zsh/custom/themes"/*(ND))
    if [[ ${#files[@]} -gt 0 ]]; then
      cp $DOTFILES/oh-my-zsh/custom/themes/* ${ZSH_CUSTOM:-${ZSH:-~/.oh-my-zsh}/custom/themes}
    fi
  fi
}

# Function wrapping the dotfiles completions dir copy over commands
cp_zsh_completions() {
  if [[ ! -d $HOME/.oh-my-zsh/completions ]]; then
    mkdir $HOME/.oh-my-zsh/completions
  fi
  cp $DOTFILES/oh-my-zsh/completions/*(.) $HOME/.oh-my-zsh/completions
}

# Easy way to login for AWS
aws_plz() {
  aws-sso login
  aws-sso-profile `aws-sso | fzf | awk -F ' *\\| *' '{print $7}'`
}


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
