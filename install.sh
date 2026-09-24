#!/usr/bin/env bash
#
# Idempotent dotfiles installer for macOS and Linux. Safe to re-run at any
# time: existing tools are skipped, plugins are updated, and anything this
# script would replace is backed up with a timestamped ".dfsave" suffix.
#
# Usage: ./install.sh [-bf|--brewfile] [-sk|--ssh-keygen EMAIL] [-h|--help]

# Refuse to be sourced: `exit` and `exec` would take the calling shell with it.
if [ -n "${ZSH_VERSION:-}" ] || { [ -n "${BASH_VERSION:-}" ] && [ "${BASH_SOURCE[0]}" != "$0" ]; }; then
  echo "Run ./install.sh instead of sourcing it." >&2
  # shellcheck disable=SC2317
  return 1 2>/dev/null || exit 1
fi

set -euo pipefail

usage() {
  cat <<EOF
Usage: ./install.sh [options]

  -bf, --brewfile          Install the packages listed in the Brewfile
  -sk, --ssh-keygen EMAIL  Generate an ed25519 ssh key for EMAIL (skipped if one exists)
  -h,  --help              Show this help
EOF
}

info() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mWarning:\033[0m %s\n' "$*" >&2; }
die() { printf '\033[1;31mError:\033[0m %s\n' "$*" >&2; exit 1; }
have() { command -v "$1" >/dev/null 2>&1; }

# Parse command line args
INSTALL_BREWFILE=false
SSH_EMAIL=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -bf|--brewfile) INSTALL_BREWFILE=true ;;
    -sk|--ssh-keygen)
      [[ $# -ge 2 && -n "$2" && "$2" != -* ]] || die "$1 requires an email address"
      SSH_EMAIL="$2"
      shift ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; die "Unknown option: $1" ;;
  esac
  shift
done

# Resolve the repo location from the script itself so the clone can live anywhere.
DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export DOTFILES

OS="$(uname -s)"
case "$OS" in
  Darwin|Linux) ;;
  *) die "Unsupported system: $OS" ;;
esac

BACKUP_SUFFIX=".dfsave.$(date +%Y%m%d%H%M%S)"
OMZ="$HOME/.oh-my-zsh"
XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"

# Run a command as root, via sudo when we aren't root already.
as_root() {
  if [[ $EUID -eq 0 ]]; then
    "$@"
  elif have sudo; then
    sudo "$@"
  else
    warn "Need root to run '$*' but sudo is unavailable"
    return 1
  fi
}

# Symlink $1 to $2. Already-correct links are left alone, other symlinks and
# identical copies are replaced, and anything else is backed up first.
link() {
  local src="$1" dest="$2"
  if [[ -L "$dest" && "$(readlink "$dest")" == "$src" ]]; then
    return 0
  fi
  mkdir -p "$(dirname "$dest")"
  if [[ -L "$dest" ]]; then
    rm "$dest"
  elif [[ -f "$dest" ]] && cmp -s "$src" "$dest"; then
    rm "$dest"
  elif [[ -e "$dest" ]]; then
    mv "$dest" "$dest$BACKUP_SUFFIX"
    info "Backed up $dest to $dest$BACKUP_SUFFIX"
  fi
  ln -s "$src" "$dest"
  info "Linked $dest -> $src"
}

# Clone a repo, or fast-forward it if it's already there.
git_sync() {
  local url="$1" dest="$2"
  if [[ -d "$dest/.git" ]]; then
    git -C "$dest" pull --ff-only --quiet || warn "Couldn't update $dest"
  else
    [[ -e "$dest" ]] && mv "$dest" "$dest$BACKUP_SUFFIX"
    git clone --depth=1 --quiet "$url" "$dest"
  fi
}

# --- Homebrew ----------------------------------------------------------------

load_brew() {
  local brew_bin
  for brew_bin in /opt/homebrew/bin/brew /usr/local/bin/brew \
      /home/linuxbrew/.linuxbrew/bin/brew "$HOME/.linuxbrew/bin/brew"; do
    if [[ -x "$brew_bin" ]]; then
      eval "$("$brew_bin" shellenv)"
      return 0
    fi
  done
  return 1
}

ensure_brew() {
  have brew && return 0
  load_brew && return 0

  info "Installing Homebrew..."
  if [[ "$OS" == Linux ]]; then
    # https://docs.brew.sh/Homebrew-on-Linux#requirements
    if have apt-get; then
      linux_pkg_install build-essential procps curl file git
    elif have dnf; then
      as_root dnf group install -y development-tools || true
      linux_pkg_install procps-ng curl file git
    fi
  fi
  # Without a terminal the installer can't prompt, so tell it not to.
  [[ -t 0 ]] || export NONINTERACTIVE=1
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  load_brew || die "Homebrew was installed but brew couldn't be found"
}

# --- Packages ----------------------------------------------------------------

linux_pkg_install() {
  if have apt-get; then
    as_root apt-get update -qq
    as_root env DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "$@"
  elif have dnf; then
    as_root dnf install -y -q "$@"
  elif have yum; then
    as_root yum install -y -q "$@"
  elif have pacman; then
    as_root pacman -Sy --needed --noconfirm "$@"
  elif have zypper; then
    as_root zypper --non-interactive install "$@"
  elif have apk; then
    as_root apk add --no-cache "$@"
  else
    ensure_brew
    brew install "$@"
  fi
}

install_core_packages() {
  local missing=() cmd
  for cmd in git curl zsh vim tmux; do
    have "$cmd" || missing+=("$cmd")
  done
  [[ ${#missing[@]} -eq 0 ]] && return 0

  info "Installing ${missing[*]}..."
  if [[ "$OS" == Darwin ]]; then
    brew install "${missing[@]}"
  else
    linux_pkg_install "${missing[@]}"
  fi
}

# Homebrew is the package manager on macOS. On Linux the system package
# manager handles the basics, and Homebrew is only needed for the Brewfile.
if [[ "$OS" == Darwin || "$INSTALL_BREWFILE" == true ]]; then
  ensure_brew
fi

install_core_packages

if [[ "$INSTALL_BREWFILE" == true ]]; then
  info "Installing Brewfile packages..."
  brew bundle --file "$DOTFILES/Brewfile"
fi

# --- zsh & Oh My Zsh ---------------------------------------------------------

info "Setting up zsh & Oh My Zsh..."

login_shell() {
  if [[ "$OS" == Darwin ]]; then
    dscl . -read "/Users/$(id -un)" UserShell 2>/dev/null | awk '{print $2}'
  else
    getent passwd "$(id -un)" 2>/dev/null | cut -d: -f7
  fi
}

current_shell="$(login_shell || true)"
if [[ "$(basename "${current_shell:-}")" != zsh ]]; then
  zsh_path="$(command -v zsh)"
  if ! grep -qxF "$zsh_path" /etc/shells 2>/dev/null; then
    info "Adding $zsh_path to /etc/shells..."
    printf '%s\n' "$zsh_path" | as_root tee -a /etc/shells >/dev/null || true
  fi
  info "Setting zsh as the default shell..."
  if have chsh; then
    chsh -s "$zsh_path" || as_root chsh -s "$zsh_path" "$(id -un)" \
      || warn "Couldn't change the login shell; run: chsh -s $zsh_path"
  else
    warn "chsh not found; set your login shell to $zsh_path manually"
  fi
fi

# Clone directly rather than running the OMZ installer, which rewrites ~/.zshrc.
if [[ ! -f "$OMZ/oh-my-zsh.sh" ]]; then
  info "Installing Oh My Zsh..."
  [[ -e "$OMZ" ]] && mv "$OMZ" "$OMZ$BACKUP_SUFFIX"
  git clone --depth=1 --quiet https://github.com/ohmyzsh/ohmyzsh.git "$OMZ"
fi

ZSH_CUSTOM_DIR="$OMZ/custom"
mkdir -p "$ZSH_CUSTOM_DIR/plugins" "$ZSH_CUSTOM_DIR/themes"

# Link (not copy) the dotfiles' custom files into the OMZ custom dir, so
# edits take effect immediately. Symlinking the whole custom dir breaks
# `omz update`, so link each entry instead.
for src in "$DOTFILES"/oh-my-zsh/custom/*.zsh \
    "$DOTFILES"/oh-my-zsh/custom/plugins/* \
    "$DOTFILES"/oh-my-zsh/custom/themes/*; do
  [[ -e "$src" ]] || continue
  link "$src" "$ZSH_CUSTOM_DIR/${src#"$DOTFILES"/oh-my-zsh/custom/}"
done

# https://github.com/zsh-users/zsh-autosuggestions/blob/master/INSTALL.md#oh-my-zsh
git_sync https://github.com/zsh-users/zsh-autosuggestions.git "$ZSH_CUSTOM_DIR/plugins/zsh-autosuggestions"
# https://github.com/zsh-users/zsh-syntax-highlighting/blob/master/INSTALL.md#oh-my-zsh
git_sync https://github.com/zsh-users/zsh-syntax-highlighting.git "$ZSH_CUSTOM_DIR/plugins/zsh-syntax-highlighting"

link "$DOTFILES/.zshrc" "$HOME/.zshrc"

# --- Vim ---------------------------------------------------------------------

info "Setting up Vim..."

link "$DOTFILES/vim" "$HOME/.vim"
link "$DOTFILES/.vimrc" "$HOME/.vimrc"

info "Installing Vim plugins..."
vim -Nu "$HOME/.vimrc" -i NONE -es -c 'PlugInstall --sync' -c 'qa!' </dev/null \
  || warn "Vim plugin install reported errors; run :PlugInstall inside Vim"

# --- tmux --------------------------------------------------------------------

info "Setting up tmux..."

link "$DOTFILES/.tmux.conf" "$HOME/.tmux.conf"

# --- git ---------------------------------------------------------------------

info "Setting up git..."

# Machine-specific settings (work email, signing program, ...) belong in
# ~/.gitconfig.local, which the shared config includes. The first time, move a
# pre-existing real ~/.gitconfig there so none of its settings are lost.
if [[ -f "$HOME/.gitconfig" && ! -L "$HOME/.gitconfig" && ! -e "$HOME/.gitconfig.local" ]]; then
  mv "$HOME/.gitconfig" "$HOME/.gitconfig.local"
  info "Moved your existing ~/.gitconfig to ~/.gitconfig.local (it overrides the shared config)"
fi
link "$DOTFILES/.gitconfig" "$HOME/.gitconfig"
link "$DOTFILES/git/ignore" "$XDG_CONFIG_HOME/git/ignore"

# zdiff3 needs git >= 2.35 (e.g. Ubuntu 22.04 ships 2.34); fall back to diff3.
git_version="$(git --version | awk '{print $3}')"
if [[ "$(printf '%s\n' 2.35 "$git_version" | sort -V | head -n1)" != 2.35 ]]; then
  git config --file "$HOME/.gitconfig.local" merge.conflictStyle diff3
fi

# Older versions of this script linked the repo's .gitignore as the global one.
if [[ -L "$HOME/.gitignore" && "$(readlink "$HOME/.gitignore")" == "$DOTFILES/.gitignore" ]]; then
  rm "$HOME/.gitignore"
fi

# --- SSH key -----------------------------------------------------------------

if [[ -n "$SSH_EMAIL" ]]; then
  info "Setting up an ssh key..."
  ssh_key="$HOME/.ssh/id_ed25519"
  mkdir -p "$HOME/.ssh"
  chmod 700 "$HOME/.ssh"

  if [[ -f "$ssh_key" ]]; then
    info "$ssh_key already exists, not generating a new one"
  else
    ssh-keygen -t ed25519 -C "$SSH_EMAIL" -f "$ssh_key"
  fi

  if [[ "$OS" == Darwin ]]; then
    # Have ssh load the key from the keychain automatically after reboots.
    # https://docs.github.com/en/authentication/connecting-to-github-with-ssh/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent
    if ! grep -qs 'UseKeychain' "$HOME/.ssh/config"; then
      printf '\nHost github.com\n  AddKeysToAgent yes\n  UseKeychain yes\n  IdentityFile ~/.ssh/id_ed25519\n' >> "$HOME/.ssh/config"
      chmod 600 "$HOME/.ssh/config"
    fi
    ssh-add --apple-use-keychain "$ssh_key" || warn "Couldn't add the key to the ssh agent"
  elif [[ -n "${SSH_AUTH_SOCK:-}" ]]; then
    ssh-add "$ssh_key" || warn "Couldn't add the key to the ssh agent"
  fi

  info "Add this public key to https://github.com/settings/keys:"
  cat "$ssh_key.pub"
fi

info "Done!"

# Start a fresh zsh with the new config, but only when someone's watching.
if [[ -t 0 && -t 1 ]]; then
  exec zsh -l
fi
