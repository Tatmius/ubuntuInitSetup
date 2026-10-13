# shellcheck shell=bash
# Key-only SSH: a drop-in that turns password logins off (used only when keys were given).

SSHD_DROPIN=/etc/ssh/sshd_config.d/10-ubuntu-init-keys-only.conf

sshd_keys_only() {
  local tmp
  say "== sshd: disable password login"
  if [[ ! -d /etc/ssh/sshd_config.d ]] && ! dry; then
    warn "no /etc/ssh/sshd_config.d (openssh-server missing?); password login NOT disabled"
    return 0
  fi
  tmp=$(mktemp)
  cat > "$tmp" <<'CONF'
# Managed by ubuntuInitSetup: SSH keys were provisioned, so password logins are off.
# The first value wins in sshd, and this file sorts before e.g. 50-cloud-init.conf.
PasswordAuthentication no
KbdInteractiveAuthentication no
CONF
  install_if_changed "$tmp" "$SSHD_DROPIN" 0644 root:root
  rm -f "$tmp"
  dry && return 0
  mkdir -p /run/sshd
  sshd -t || die "sshd -t failed; check $SSHD_DROPIN"
  local eff
  eff=$(sshd -T 2>/dev/null || true)   # capture first: grep -q on a pipe + pipefail = false alarms
  if grep -qx 'passwordauthentication no' <<<"$eff"; then
    say "sshd: passwordauthentication no (effective)"
  else
    warn "sshd -T does not report 'passwordauthentication no'; check other sshd config files"
  fi
  systemctl reload ssh 2>/dev/null || systemctl try-restart ssh 2>/dev/null || true
}
