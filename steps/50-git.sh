# shellcheck shell=bash
# Step 6: git settings for root: default branch "main", and user.name / user.email
# from the options (or asked for when interactive).

step_git() {
  local name=$GIT_NAME email=$GIT_EMAIL
  say "== git config (root)"
  run git config --global init.defaultBranch main

  if [[ -z $name ]] && is_interactive; then
    read -rp "Enter git user.name: " name
  fi
  if [[ -z $email ]] && is_interactive; then
    read -rp "Enter git user.email: " email
  fi

  if [[ -n $name ]]; then
    run git config --global user.name "$name"
  fi
  if [[ -n $email ]]; then
    run git config --global user.email "$email"
  fi
  if [[ -z $name && -z $email ]]; then
    say "git user.name/email not set (none given)"
  fi
}
