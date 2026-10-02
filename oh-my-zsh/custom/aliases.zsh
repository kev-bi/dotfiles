# Shortcuts
#
# Restart the zsh session to properly reload zshrc.
alias rzsh="exec zsh"
# Delete all local branches except main, master, and the current branch.
alias gbp='git for-each-ref --format="%(refname:short)" refs/heads | grep -vxE "main|master|$(git branch --show-current)" | xargs -r git branch -D'
# Alias for kubectl
alias kc=kubecolor
