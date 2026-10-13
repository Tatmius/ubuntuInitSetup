# shellcheck shell=bash
# Step 8: unattended-upgrades (security + updates, no automatic reboot).

step_unattended() {
  local tmp
  [[ $DO_UNATTENDED == 1 ]] || { say "== unattended-upgrades skipped (--no-unattended)"; return 0; }
  say "== unattended-upgrades"
  tmp=$(mktemp)
  cat > "$tmp" <<'CONF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Unattended-Upgrade "1";
CONF
  install_if_changed "$tmp" /etc/apt/apt.conf.d/20auto-upgrades 0644 root:root
  cat > "$tmp" <<'CONF'
Unattended-Upgrade::Allowed-Origins {
        "${distro_id}:${distro_codename}-security";
        "${distro_id}:${distro_codename}-updates";
};
Unattended-Upgrade::Mail "root";           // change to an e-mail address if needed
Unattended-Upgrade::MailOnlyOnError "true";
Unattended-Upgrade::Automatic-Reboot "false";
CONF
  install_if_changed "$tmp" /etc/apt/apt.conf.d/50unattended-upgrades 0644 root:root
  rm -f "$tmp"
}
