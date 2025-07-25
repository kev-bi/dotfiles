#!/usr/bin/env bash

echo "Setting up your system..."

# Parse command line args
# See https://rowannicholls.github.io/bash/intro/passing_arguments.html
while [[ "$#" -gt 0 ]]
do case $1 in
    -bf|--brewfile) brewfile=true
    shift;;
    -sk|--ssh-keygen) email=$2
    shift;;
esac
shift
done

INSTALL_BREWFILE=${brewfile:-false}

# Export env variables
export DOTFILES="$HOME/.dotfiles"

# Check for Homebrew and install if we don't have it
# Use command -v according to https://stackoverflow.com/questions/592620/how-can-i-check-if-a-program-exists-from-a-bash-script
if ! command -v brew >/dev/null 2>&1; then
  echo "Installing brew..."

  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  if [ $(uname) == "Darwin" ]; then
    echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> $HOME/.zprofile
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [ $(uname) == "Linux" ]; then
    echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >> $HOME/.zprofile
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
  else
    echo "Unrecognized system, couldn't install brew..."
    exit 1
  fi
fi

# Update Homebrew recipes
brew update

# Install all our dependencies with bundle (See Brewfile)
if [ $INSTALL_BREWFILE = true ]; then
  brew bundle --file ./Brewfile
fi

echo "Setting up zsh & oh-my-zsh..."

# Check for zsh and install if we don't have it
if ! command -v zsh >/dev/null 2>&1; then
  echo "Installing zsh..."

  brew install zsh

  # Add zsh to the list of valid shells
  echo "Adding the following path to the list of valid shells..."
  command -v zsh | sudo tee -a /etc/shells
fi

# Check for Oh My Zsh and install if we don't have it
if [[ ! -n $ZSH ]]; then
  echo "Installing oh-my-zsh..."
  echo "NOTICE: Once zsh is set up you may need to log out and log in..."

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

# https://github.com/zsh-users/zsh-autosuggestions/blob/master/INSTALL.md#oh-my-zsh
git clone https://github.com/zsh-users/zsh-autosuggestions "${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions"

# https://github.com/zsh-users/zsh-syntax-highlighting/blob/master/INSTALL.md#oh-my-zsh
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting"

# https://github.com/romkatv/powerlevel10k?tab=readme-ov-file#oh-my-zsh
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k"

# Handle existing .zshrc file (if it exists); backup unless it's a soft link
if [[ -f $HOME/.zshrc ]]; then
  if [[ ! -L $HOME/.zshrc ]]; then
    mv $HOME/.zshrc $HOME/.zshrc.dfsave
  else
    rm $HOME/.zshrc
  fi
fi
# Symlinks the .zshrc file from the .dotfiles
ln -s $DOTFILES/.zshrc $HOME/.zshrc

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
ln -s $DOTFILES/vim $HOME/.vim

# Handle existing .vimrc file (if it exists); backup unless it's a soft link
if [[ -f $HOME/.vimrc ]]; then
  if [[ ! -L $HOME/.vimrc ]]; then
    mv $HOME/.vimrc $HOME/.vimrc.dfsave
  else
    rm $HOME/.vimrc
  fi
fi
# Symlinks the .vimrc file from the .dotfiles
ln -s $DOTFILES/.vimrc $HOME/.vimrc

# Install Vim plugins
vim +PlugInstall +qall

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
ln -s $DOTFILES/.gitconfig $HOME/.gitconfig

# Handle existing .gitignore file (if it exists); backup unless it's a soft link
if [[ -f $HOME/.gitignore ]]; then
  if [[ ! -L $HOME/.gitignore ]]; then
    mv $HOME/.gitignore $HOME/.gitignore.dfsave
  else
    rm $HOME/.gitignore
  fi
fi
# Symlinks the .gitignore file from the .dotfiles
ln -s $DOTFILES/.gitignore $HOME/.gitignore

# Handle existing .tmux.conf file (if it exists); backup unless it's a soft link
if [[ -f $HOME/.tmux.conf ]]; then
  if [[ ! -L $HOME/.tmux.conf ]]; then
    mv $HOME/.tmux.conf $HOME/.tmux.conf.dfsave
  else
    rm $HOME/.tmux.conf
  fi
fi
# Symlinks the .tmux.conf file from the .dotfiles
ln -s $DOTFILES/.tmux.conf $HOME/.tmux.conf

if [[ -n "${email+1}" ]]; then
  ssh-keygen -t ed25519 -C $email
  eval "$(ssh-agent -s)"
  if [ $(uname) == "Darwin" ]; then
    ssh-add --apple-use-keychain ~/.ssh/id_ed25519
  elif [ $(uname) == "Linux" ]; then
    ssh-add ~/.ssh/id_ed25519
  else
    echo "Unrecognized system, couldn't install setup ssh-key..."
  fi
fi

# Reload the shell
exec zsh
