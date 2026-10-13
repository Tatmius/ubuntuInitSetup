# shellcheck shell=bash
# Step 6: git defaults for root (default branch main, optional name/email).

step_git() {
  local name=$GIT_NAME email=$GIT_EMAIL
  say "== git config (root)"
  run git config --global init.defaultBranch main
  if [[ -z $name ]] && interactive; then read -rp "Enter git user.name: " name; fi
  if [[ -z $email ]] && interactive; then read -rp "Enter git user.email: " email; fi
  if [[ -n $name ]]; then run git config --global user.name "$name"; fi
  if [[ -n $email ]]; then run git config --global user.email "$email"; fi
  if [[ -z $name && -z $email ]]; then say "git user.name/email not set (none given)"; fi
}
