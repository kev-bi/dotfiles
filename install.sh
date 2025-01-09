#!/bin/bash

echo "Setting up your Mac..."

# Export env variables
export DOTFILES="$HOME/.dotfiles"

# Check for Homebrew and install if we don't have it
# Use command -v according to https://stackoverflow.com/questions/592620/how-can-i-check-if-a-program-exists-from-a-bash-script
if ! command -v brew >/dev/null 2>&1; then
  echo "Installing brew..."

  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> $HOME/.zprofile
  eval "$(/opt/homebrew/bin/brew shellenv)"

  # Update Homebrew recipes
  brew update
fi

echo "Setting up zsh & oh-my-zsh..."

# Check for zsh and install if we don't have it
if ! command -v zsh >/dev/null 2>&1; then
  echo "Installing zsh..."

  brew install zsh
  # Make zsh the default environment
  chsh -s $(which zsh)
fi

# Check for Oh My Zsh and install if we don't have it
if [[ ! -n $ZSH ]]; then
  echo "Installing oh-my-zsh..."

  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/HEAD/tools/install.sh)"
fi

# Copy over dotfiles custom directory files and subdirectories to the
# Oh My Zsh custom directory. This is a workaround because if the custom
# directory is a softlink Oh My Zsh errors when updating.
find $DOTFILES/oh-my-zsh/custom -type f -exec cp {} $HOME/.oh-my-zsh/custom \;
if [[ -d $DOTFILES/oh-my-zsh/custom/plugins ]]; then
  cp -r $DOTFILES/oh-my-zsh/custom/plugins/* $HOME/.oh-my-zsh/custom/plugins
fi
if [[ -d $DOTFILES/oh-my-zsh/custom/themes ]]; then
  cp $DOTFILES/oh-my-zsh/custom/themes/* $HOME/.oh-my-zsh/custom/themes
fi

# Handle existing .zshrc file (if it exists); backup unless it's a soft link
if [[ -f $HOME/.zshrc ]]; then
  if [[ ! -L $HOME/.zshrc ]]; then
    mv $HOME/.zshrc $HOME/.zshrc.dfsave
  else
    rm $HOME/.zshrc
  fi
fi
# Symlinks the .zshrc file from the .dotfiles
ln -sw $DOTFILES/.zshrc $HOME/.zshrc

echo "Setting up Vim..."

# Handle existing .vim dir (if it exists); backup unless it's a soft link
if [[ -d $HOME/.vim ]]; then
  if [[ ! -L $HOME/.vim ]]; then
    mv $HOME/.vim $HOME/.vim.dfsave
  else
    rm $HOME/.vim
  fi
fi
# Symlinks the .vim dir from the .dotfiles
ln -sw $DOTFILES/vim $HOME/.vim

# Handle existing .vimrc file (if it exists); backup unless it's a soft link
if [[ -f $HOME/.vimrc ]]; then
  if [[ ! -L $HOME/.vimrc ]]; then
    mv $HOME/.vimrc $HOME/.vimrc.dfsave
  else
    rm $HOME/.vimrc
  fi
fi
# Symlinks the .vimrc file from the .dotfiles
ln -sw $DOTFILES/.vimrc $HOME/.vimrc

echo "Setting up git..."

# Handle existing .gitconfig file (if it exists); backup unless it's a soft link
if [[ -f $HOME/.gitconfig ]]; then
  if [[ ! -L $HOME/.gitconfig ]]; then
    mv $HOME/.gitconfig $HOME/.gitconfig.dfsave
  else
    rm $HOME/.gitconfig
  fi
fi
# Symlinks the .gitconfig file from the .dotfiles
ln -sw $DOTFILES/.gitconfig $HOME/.gitconfig

# Handle existing .gitignore file (if it exists); backup unless it's a soft link
if [[ -f $HOME/.gitignore ]]; then
  if [[ ! -L $HOME/.gitignore ]]; then
    mv $HOME/.gitignore $HOME/.gitignore.dfsave
  else
    rm $HOME/.gitignore
  fi
fi
# Symlinks the .gitignore file from the .dotfiles
ln -sw $DOTFILES/.gitignore $HOME/.gitignore

# Reload the shell
exec zsh
