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
    cp -r $DOTFILES/oh-my-zsh/custom/plugins/* $HOME/.oh-my-zsh/custom/plugins
  fi
  if [[ -d $DOTFILES/oh-my-zsh/custom/themes ]]; then
    cp $DOTFILES/oh-my-zsh/custom/themes/* $HOME/.oh-my-zsh/custom/themes
  fi
}

# Function wrapping the dotfiles custom dir copy over commands
cp_zsh_completions() {
  if [[ ! -d $HOME/.oh-my-zsh/completions ]]; then
    mkdir $HOME/.oh-my-zsh/completions
  fi
  cp $DOTFILES/oh-my-zsh/completions/*(.) $HOME/.oh-my-zsh/completions
}

# Get the argo password
argo_passwd() {
  k -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d
}

# Easy way to login for AWS
aws_plz() {
  aws-sso login
  aws-sso-profile `aws-sso | fzf | awk -F ' *\\| *' '{print $7}'`
}

# Install krew
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
