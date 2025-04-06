# Add directories to the PATH unless already present
add_to_path() {
  if [[ -d "$1" ]] && [[ ":$PATH:" != *":$1:"* ]]; then
    export PATH="$1:$PATH"
  fi
}

# Function wrapping the dotfiles custom dir copy over commands
cp_zsh_custom() {
  cp $DOTFILES/oh-my-zsh/custom/*(.) ${ZSH_CUSTOM:-${ZSH:-~/.oh-my-zsh}/custom}
  if [[ -d $DOTFILES/oh-my-zsh/custom/plugins ]]; then
    cp -r $DOTFILES/oh-my-zsh/custom/plugins/* ${ZSH_CUSTOM:-${ZSH:-~/.oh-my-zsh}/custom/plugins}
  fi
  if [[ -d $DOTFILES/oh-my-zsh/custom/themes ]]; then
    cp $DOTFILES/oh-my-zsh/custom/themes/* ${ZSH_CUSTOM:-${ZSH:-~/.oh-my-zsh}/custom/themes}
  fi
}
