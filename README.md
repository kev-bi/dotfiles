# Install

Works on macOS and Linux (apt, dnf, yum, pacman, zypper, apk). The install
script is idempotent, so re-run it any time to pick up changes or update
plugins.

1. Clone this repo to `~/.dotfiles` (HTTPS works before you have an ssh key)

    ```
    git clone https://github.com/kev-bi/dotfiles.git ~/.dotfiles
    ```

2. Run the install script (don't `source` it)

    ```
    ~/.dotfiles/install.sh
    ```

    Pass the following flag to install the packages in the Brewfile
    ```
    -bf|--brewfile
    ```

    Pass the following flag along with email to set up an ssh-key on the machine
    ```
    -sk|--ssh-keygen "your_email@example.com"
    ```

3. [Generate](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent) a new ssh key if you didn't pass the `-sk` or `--ssh-keygen` flag in the previous step

4. [Add](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/adding-a-new-ssh-key-to-your-github-account) the new ssh key to your github account, then switch the remote to ssh

    ```
    git -C ~/.dotfiles remote set-url origin git@github.com:kev-bi/dotfiles.git
    ```

## What gets installed

| Repo file | Linked to |
| --- | --- |
| `.zshrc` | `~/.zshrc` |
| `oh-my-zsh/custom/*` | `~/.oh-my-zsh/custom/*` |
| `.vimrc`, `vim/` | `~/.vimrc`, `~/.vim` |
| `.tmux.conf` | `~/.tmux.conf` |
| `.gitconfig` | `~/.gitconfig` |
| `git/ignore` | `~/.config/git/ignore` (global gitignore) |

Anything already at those paths is moved aside with a `.dfsave.<timestamp>`
suffix. An existing real `~/.gitconfig` is moved to `~/.gitconfig.local`
instead, so its settings keep applying.

## Machine-specific settings

These files are loaded if present and are not tracked:

- `~/.zshrc.local`: extra shell config (work env vars, secrets, ...)
- `~/.gitconfig.local`: git overrides, e.g. a work email or signing program

    ```
    [user]
    	email = you@work.com
    ```

# Troubleshooting

## brew install gcc

When installing gcc with brew there is a possibility you will get the following error:

```
Warning: The post-install step did not complete successfully
You can try again using:
  brew postinstall gcc
```

In this case you will need to follow these directions to install some additional [requirements](https://docs.brew.sh/Homebrew-on-Linux#requirements). Then ` brew postinstall gcc` should work.

# Vim

## Setting up Go LSP

1. Install gopls with `go install golang.org/x/tools/gopls@latest`

## Setting up Python Linting and LSP

1. Create virtual environment for the directory with `mkv`

2. Install dependencies (pylsp, ruff etc) with `pip install -r  requirements.txt`

## Installing new plugins

1. Add a `Plug '...'` line to the plugin section of the .vimrc and save it - `:w`

2. Source the .vimrc file - `:source ~/.vimrc`

3. `:PlugInstall`

Plugins live in `vim/plugged/`, which is gitignored. `:PlugUpdate` updates
them, and `:PlugSnapshot` writes a script that pins the current versions.

# Acknowledgements / Resources

- Dries Vints' [dotfiles](https://github.com/driesvints/dotfiles)
- This [.vimrc](https://www.freecodecamp.org/news/vimrc-configuration-guide-customize-your-vim-editor/) setup
- This blog on [`--updates-refs`](https://andrewlock.net/working-with-stacked-branches-in-git-is-easier-with-update-refs/)
