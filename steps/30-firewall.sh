# shellcheck shell=bash
# Step 4: ufw firewall (deny incoming, allow ssh).
# Failures are only warnings: ufw often cannot work inside an unprivileged LXC
# container. Use the Proxmox firewall there instead (--no-ufw).

step_ufw() {
  if [[ $SETUP_UFW != yes ]]; then
    say "== ufw skipped (--no-ufw)"
    return 0
  fi
  say "== ufw"
  if ! command -v ufw >/dev/null; then
    run_or_warn apt-get install -y ufw
  fi
  if configure_ufw; then
    run_or_warn ufw status verbose
  else
    warn "ufw setup failed (unprivileged LXC?); firewall NOT active, use the Proxmox firewall"
  fi
}

# configure_ufw: returns non-zero as soon as one ufw command fails.
configure_ufw() {
  run ufw default deny incoming || return 1
  run ufw default allow outgoing || return 1
  run ufw allow ssh || return 1
  run ufw --force enable || return 1
}
