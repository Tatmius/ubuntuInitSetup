# shellcheck shell=bash
# operator.sh - the key-only operator user (default "llm-operator") used by
# automation: SSH key login only, password locked, never in "sudo" or "adm".
# What it may run as root is limited by its sudoers file (see sudoers.sh).

setup_operator_if_keys_given() {
  local name=$1 key_file=$2
  if [[ -s $key_file ]]; then
    setup_operator_user "$name" "$key_file"
  else
    say "no operator keys given: operator user not created"
  fi
}

setup_operator_user() {
  local name=$1 key_file=$2
  say "== operator user $name"
  if id "$name" >/dev/null 2>&1; then
    say "user $name exists"
  else
    run useradd --create-home --shell /bin/bash --comment "automation operator" "$name"
  fi
  run usermod --shell /bin/bash -L "$name"     # -L locks the password: key login only
  remove_from_group_if_member "$name" sudo
  remove_from_group_if_member "$name" adm
  install_authorized_keys "$name" "$key_file" replace
  install_operator_sudoers "$name"
}

remove_from_group_if_member() {
  local name=$1 group=$2
  if id -nG "$name" 2>/dev/null | tr ' ' '\n' | grep -qx "$group"; then
    run gpasswd -d "$name" "$group"
  fi
}
