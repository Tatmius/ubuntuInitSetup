# shellcheck shell=bash
# Operator sudoers: render the template, validate with visudo, install as 0440.

# render_sudoers USER: template (+ optional --sudoers-extra file) with @OPERATOR@ replaced.
render_sudoers() {
  sed "s/@OPERATOR@/$1/g" "$INIT_DIR/templates/sudoers-operator"
  if [[ -n ${SUDOERS_EXTRA:-} ]]; then
    [[ -r $SUDOERS_EXTRA ]] || die "--sudoers-extra is not readable: $SUDOERS_EXTRA"
    printf '\n# --- extra rules from %s ---\n' "$(basename "$SUDOERS_EXTRA")"
    sed "s/@OPERATOR@/$1/g" "$SUDOERS_EXTRA"
  fi
}

# install_operator_sudoers USER: nothing is installed unless visudo accepts the file.
install_operator_sudoers() {
  local name=$1 tmp dest=/etc/sudoers.d/$1
  tmp=$(mktemp)
  render_sudoers "$name" > "$tmp"
  if command -v visudo >/dev/null; then
    if ! visudo -cf "$tmp" >/dev/null; then
      visudo -cf "$tmp" || true
      rm -f "$tmp"; die "sudoers check failed; nothing installed"
    fi
  elif ! dry; then
    rm -f "$tmp"; die "visudo not found (is sudo installed?)"
  fi
  install_if_changed "$tmp" "$dest" 0440 root:root
  rm -f "$tmp"
  if ! dry; then visudo -c >/dev/null || die "visudo -c failed after installing $dest"; fi
}
