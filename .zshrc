# Short-circuit for Cursor agent
if [[ "$CURSOR_AGENT" == "1" ]]; then
  return
fi

# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

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

path=(
  "$HOME/.local/bin"
  "$HOME/bin"
  "$HOME/go/bin"
  "$HOME/.pixi/bin"
  "${KREW_ROOT:-$HOME/.krew}/bin"
  $path
  /Applications/Postgres.app/Contents/Versions/latest/bin
)
path=($^path(N-/))  # drop directories that don't exist

# OH MY ZSH -------------------------------------------------------------------

# Path to your Oh My Zsh installation
export ZSH="$HOME/.oh-my-zsh"

# Use Powerlevel10k when it's installed.
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
if [[ -d "$ZSH/custom/themes/powerlevel10k" ]]; then
  ZSH_THEME="powerlevel10k/powerlevel10k"
else
  ZSH_THEME="robbyrussell"
fi

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
plugins=(aliases git python virtualenv)

# Plugins for tools that may not be installed on every machine. The OMZ
# plugins also cache each tool's completion script instead of regenerating it
# on every shell start.
(( $+commands[bazel] )) && plugins+=(bazel)
(( $+commands[kubectl] )) && plugins+=(kubectl)
(( $+commands[helm] )) && plugins+=(helm)
(( $+commands[minikube] )) && plugins+=(minikube)
(( $+commands[fzf] )) && plugins+=(fzf)

# zsh-syntax-highlighting must be the last plugin
plugins+=(zsh-autosuggestions zsh-syntax-highlighting)

# Extra completions (added before OMZ runs compinit):
# - the dotfiles' own completion scripts
# - https://github.com/zsh-users/zsh-completions#oh-my-zsh (loaded via fpath,
#   not as a plugin: https://github.com/zsh-users/zsh-completions/issues/603)
fpath+=(
  "$DOTFILES/oh-my-zsh/completions"
  "$ZSH/custom/plugins/zsh-completions/src"
)

source $ZSH/oh-my-zsh.sh

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

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

export GOPRIVATE=buf.build/gen/go

# k9s: force xterm-256color so tcell recognizes Shift-Left/Right (column select).
# tcell's built-in tmux-256color lacks the shift-arrow key mappings.
alias k9s='TERM=xterm-256color k9s'

# COMPLETIONS -----------------------------------------------------------------

# Bash-style `complete` support, for tools that only ship bash completions.
# Oh My Zsh has already run compinit.
autoload -Uz bashcompinit && bashcompinit

# Source a tool's generated completion script, caching it and regenerating
# only when the tool is updated. Usage: _cached_completion TOOL GENERATE-CMD...
_cached_completion() {
  local tool=$1 cache="$ZSH_CACHE_DIR/completions/_$1"
  shift
  (( $+commands[$tool] )) || return 0
  if [[ ! -s $cache || $commands[$tool] -nt $cache ]]; then
    mkdir -p "${cache:h}"
    "$@" >| "$cache" 2>/dev/null
  fi
  source "$cache"
}
_cached_completion kubebuilder kubebuilder completion zsh
_cached_completion kubie kubie generate-completion
_cached_completion stern stern --completion=zsh
unfunction _cached_completion

# Have "kubecolor" borrow the same completion logic as "kubectl"
(( $+commands[kubecolor] )) && compdef kubecolor=kubectl

# Terraform
(( $+commands[terraform] )) && complete -o nospace -C "$commands[terraform]" terraform

# AWS CLI
(( $+commands[aws_completer] )) && complete -C "$commands[aws_completer]" aws

# Google Cloud SDK: PATH and completions
if [[ -n $HOMEBREW_PREFIX && -d "$HOMEBREW_PREFIX/share/google-cloud-sdk" ]]; then
  source "$HOMEBREW_PREFIX/share/google-cloud-sdk/path.zsh.inc"
  source "$HOMEBREW_PREFIX/share/google-cloud-sdk/completion.zsh.inc"
fi

# fzf completion for bazel targets: `bazel build **<TAB>`
# https://blog.jez.io/fzf-bazel/
if (( $+commands[fzf] )); then
  _fzf_complete_bazel_test() {
    _fzf_complete '-m' "$@" < <(command bazel query \
      "kind('(test|test_suite) rule', //...)" 2> /dev/null)
  }

  _fzf_complete_bazel() {
    local tokens
    tokens=(${(z)LBUFFER})

    if [ ${#tokens[@]} -ge 3 ] && [ "${tokens[2]}" = "test" ]; then
      _fzf_complete_bazel_test "$@"
    else
      # Might be able to make this better someday, by listing all repositories
      # that have been configured in a WORKSPACE.
      # See https://stackoverflow.com/questions/46229831/ or just run
      #     bazel query //external:all
      # This is the reason why things like @ruby_2_6//:ruby.tar.gz don't show up
      # in the output: they're not a dep of anything in //..., but they are deps
      # of @ruby_2_6//...
      _fzf_complete '-m' "$@" < <(command bazel query --keep_going \
        --noshow_progress \
        "kind('(binary rule)|(generated file)', deps(//...))" 2> /dev/null)
    fi
  }

  _fzf_complete_sb() { _fzf_complete_bazel "$@" }
  _fzf_complete_sbg() { _fzf_complete_bazel "$@" }
  _fzf_complete_sbgo() { _fzf_complete_bazel "$@" }
  _fzf_complete_sbo() { _fzf_complete_bazel "$@" }
  _fzf_complete_sbr() { _fzf_complete_bazel "$@" }
  _fzf_complete_sbl() { _fzf_complete_bazel "$@" }
  _fzf_complete_st() { _fzf_complete_bazel_test "$@" }
  _fzf_complete_sto() { _fzf_complete_bazel_test "$@" }
  _fzf_complete_stg() { _fzf_complete_bazel_test "$@" }
  _fzf_complete_stog() { _fzf_complete_bazel_test "$@" }
fi

# BEGIN_AWS_SSO_CLI
if (( $+commands[aws-sso] )); then
  __aws_sso_profile_complete() {
    local _args=${AWS_SSO_HELPER_ARGS:- -L error}
    _multi_parts : "($(aws-sso ${=_args} list --csv Profile))"
  }

  aws-sso-profile() {
    local _args=${AWS_SSO_HELPER_ARGS:- -L error}
    if [ -n "$AWS_PROFILE" ]; then
      echo "Unable to assume a role while AWS_PROFILE is set"
      return 1
    fi

    if [ -z "$1" ]; then
      echo "Usage: aws-sso-profile <profile>"
      return 1
    fi

    eval $(aws-sso ${=_args} eval -p "$1")
    if [ "$AWS_SSO_PROFILE" != "$1" ]; then
      return 1
    fi
  }

  aws-sso-clear() {
    local _args=${AWS_SSO_HELPER_ARGS:- -L error}
    if [ -z "$AWS_SSO_PROFILE" ]; then
      echo "AWS_SSO_PROFILE is not set"
      return 1
    fi
    eval $(aws-sso ${=_args} eval -c)
  }

  compdef __aws_sso_profile_complete aws-sso-profile
  complete -C "$commands[aws-sso]" aws-sso
fi
# END_AWS_SSO_CLI

# Machine-specific settings (work env vars, secrets, ...) that shouldn't be
# committed.
if [[ -f "$HOME/.zshrc.local" ]]; then
  source "$HOME/.zshrc.local"
fi
