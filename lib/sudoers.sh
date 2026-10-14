# shellcheck shell=bash
# sudoers.sh - build the operator's sudoers file from templates/sudoers-operator
# (plus optional --sudoers-extra rules), check it with visudo, install it as 0440.

# render_sudoers USER: print the sudoers text with @OPERATOR@ replaced by USER.
render_sudoers() {
  local name=$1
  sed "s/@OPERATOR@/$name/g" "$SCRIPT_DIR/templates/sudoers-operator"
  if [[ -n $SUDOERS_EXTRA ]]; then
    if [[ ! -r $SUDOERS_EXTRA ]]; then
      die "--sudoers-extra is not readable: $SUDOERS_EXTRA"
    fi
    printf '\n# --- extra rules from %s ---\n' "$(basename "$SUDOERS_EXTRA")"
    sed "s/@OPERATOR@/$name/g" "$SUDOERS_EXTRA"
  fi
}

# install_operator_sudoers USER: nothing is installed unless visudo accepts the file.
install_operator_sudoers() {
  local name=$1
  local new_file dest=/etc/sudoers.d/$1
  new_file=$(mktemp)
  render_sudoers "$name" > "$new_file"

  if command -v visudo >/dev/null; then
    if ! visudo -cf "$new_file" >/dev/null; then
      visudo -cf "$new_file" || true          # run again to show the error
      rm -f "$new_file"
      die "sudoers check failed; nothing installed"
    fi
  elif ! is_dry_run; then
    rm -f "$new_file"
    die "visudo not found (is sudo installed?)"
  fi

  install_file_if_changed "$new_file" "$dest" 0440 root root
  rm -f "$new_file"

  if ! is_dry_run && ! visudo -c >/dev/null; then
    die "visudo -c failed after installing $dest"
  fi
}
