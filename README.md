# Install

1. Clone this repo to `~/.dotfiles`

    ```
    git clone --recurse-submodules git@github.com:kev-bi/dotfiles.git ~/.dotfiles
    ```

    Update any submodules if needed

    ```
    git submodule update --remote
    ```

2. Run the install script

    ```
    cd ~/.dotfiles && source install.sh
    ```

3. Create [a new ssh key](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent) for github on the machine.

# Troubleshooting

## brew install gcc

When installing gcc with brew there is a possibility you will get the following error:
```
Warning: The post-install step did not complete successfully
You can try again using:
  brew postinstall gcc
```

In this case you will need to follow these directions to install some additional [requirements](https://docs.brew.sh/Homebrew-on-Linux#requirements). Then ` brew postinstall gcc` should work.

# Acknowledgements / Resources

- Dries Vints' [dotfiles](https://github.com/driesvints/dotfiles)
- This [.vimrc](https://www.freecodecamp.org/news/vimrc-configuration-guide-customize-your-vim-editor/) setup
- This blog on [`--updates-refs`](https://andrewlock.net/working-with-stacked-branches-in-git-is-easier-with-update-refs/)
