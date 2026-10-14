# shellcheck shell=bash
# sshd.sh - turn SSH password login off with a small drop-in file, but only when
# admin keys were given (otherwise the admin could be locked out).

SSHD_DROPIN=/etc/ssh/sshd_config.d/10-ubuntu-init-keys-only.conf

# setup_sshd_password_login ADMIN_KEY_FILE: decide from --ssh-keys-only / --keep-ssh-passwords.
setup_sshd_password_login() {
  local admin_key_file=$1
  case $SSH_KEYS_ONLY in
    yes) disable_ssh_password_login ;;
    no)  say "sshd unchanged (--keep-ssh-passwords)" ;;
    auto)
      if [[ -s $admin_key_file ]]; then
        disable_ssh_password_login
      else
        say "sshd unchanged (no admin keys)"
      fi
      ;;
  esac
}

disable_ssh_password_login() {
  local new_file
  say "== sshd: disable password login"
  if [[ ! -d /etc/ssh/sshd_config.d ]] && ! is_dry_run; then
    warn "no /etc/ssh/sshd_config.d (openssh-server missing?); password login NOT disabled"
    return 0
  fi
  new_file=$(mktemp)
  cat > "$new_file" <<'CONF'
# Managed by ubuntuInitSetup: SSH keys were provisioned, so password logins are off.
# The first value wins in sshd, and this file sorts before e.g. 50-cloud-init.conf.
PasswordAuthentication no
KbdInteractiveAuthentication no
CONF
  install_file_if_changed "$new_file" "$SSHD_DROPIN" 0644 root root
  rm -f "$new_file"
  if is_dry_run; then
    return 0
  fi
  check_and_reload_sshd
}

check_and_reload_sshd() {
  local effective_config
  mkdir -p /run/sshd                          # sshd -t needs it; missing with socket activation
  if ! sshd -t; then
    die "sshd -t failed; check $SSHD_DROPIN"
  fi
  effective_config=$(sshd -T 2>/dev/null || true)
  if grep -qx 'passwordauthentication no' <<< "$effective_config"; then
    say "sshd: passwordauthentication no (effective)"
  else
    warn "sshd -T does not report 'passwordauthentication no'; check other sshd config files"
  fi
  # Ubuntu 24.04 starts sshd per connection (ssh.socket), so a failed reload is fine.
  if ! systemctl reload ssh 2>/dev/null; then
    systemctl try-restart ssh 2>/dev/null || true
  fi
}
