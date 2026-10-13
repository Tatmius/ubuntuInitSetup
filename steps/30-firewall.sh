# shellcheck shell=bash
# Step 4: ufw (deny incoming, allow ssh). Failures are warnings: ufw often cannot
# work inside an unprivileged LXC; use the Proxmox firewall there (--no-ufw).

step_ufw() {
  [[ $DO_UFW == 1 ]] || { say "== ufw skipped (--no-ufw)"; return 0; }
  say "== ufw"
  command -v ufw >/dev/null || try apt-get install -y ufw
  if run ufw default deny incoming && run ufw default allow outgoing \
     && run ufw allow ssh && run ufw --force enable; then
    try ufw status verbose
  else
    warn "ufw setup failed (unprivileged LXC?); firewall NOT active, use the Proxmox firewall"
  fi
}
