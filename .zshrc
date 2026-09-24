# Path to dotfiles, resolved through the ~/.zshrc symlink
export DOTFILES="${${(%):-%x}:A:h}"

# Keep PATH and FPATH free of duplicates
typeset -U path fpath

# Homebrew (macOS: Apple silicon / Intel, Linux). This runs on every shell,
# not only login shells, so the brew paths stay first in tmux too.
for brew_bin in /opt/homebrew/bin/brew /usr/local/bin/brew \
    /home/linuxbrew/.linuxbrew/bin/brew "$HOME/.linuxbrew/bin/brew"; do
  if [[ -x $brew_bin ]]; then
    eval "$($brew_bin shellenv)"
    break
  fi
done
unset brew_bin

path=("$HOME/.local/bin" "$HOME/bin" $path)
path=($^path(N-/))  # drop directories that don't exist

# OH MY ZSH -------------------------------------------------------------------

# Path to your Oh My Zsh installation
export ZSH="$HOME/.oh-my-zsh"

# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
ZSH_THEME="robbyrussell"

# Remind to update instead of prompting at startup
zstyle ':omz:update' mode reminder

# Make repository status checks much faster in large repos
DISABLE_UNTRACKED_FILES_DIRTY="true"

# Show timestamps in `history` output
HIST_STAMPS="yyyy-mm-dd"

# Set ".venv" as virtual env name for python plugin
export PYTHON_VENV_NAME=".venv"

# Which plugins would you like to load?
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Add wisely, as too many plugins slow down shell startup.
plugins=(aliases git python)

# Plugins for tools that may not be installed on every machine. The OMZ
# plugins also cache each tool's completion script instead of regenerating it
# on every shell start.
(( $+commands[kubectl] )) && plugins+=(kubectl)
(( $+commands[helm] )) && plugins+=(helm)
(( $+commands[minikube] )) && plugins+=(minikube)
(( $+commands[fzf] )) && plugins+=(fzf)

# zsh-syntax-highlighting must be the last plugin
plugins+=(zsh-autosuggestions zsh-syntax-highlighting)

source $ZSH/oh-my-zsh.sh

# USER CONFIGURATION ----------------------------------------------------------

export LANG="${LANG:-en_US.UTF-8}"
export EDITOR="vim"
export VISUAL="$EDITOR"

# History. Oh My Zsh already enables sharing it between sessions.
HISTSIZE=100000
SAVEHIST=100000
setopt HIST_IGNORE_ALL_DUPS  # drop older duplicates of a command
setopt HIST_REDUCE_BLANKS    # trim superfluous whitespace
setopt HIST_IGNORE_SPACE     # commands starting with a space aren't saved

# Generate the kubebuilder completion script for Zsh (no OMZ plugin exists)
if (( $+commands[kubebuilder] )); then
  source <(kubebuilder completion zsh)
fi

# Machine-specific settings (work env vars, secrets, ...) that shouldn't be
# committed.
if [[ -f "$HOME/.zshrc.local" ]]; then
  source "$HOME/.zshrc.local"
fi
