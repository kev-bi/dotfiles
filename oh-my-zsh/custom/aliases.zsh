# Shortcuts
#
# Restart the zsh session to properly reload zshrc.
alias rzsh="exec zsh"
# Delete all local branches except main.
alias gbp="git branch | grep -vE \"main\" | xargs git branch -D"
