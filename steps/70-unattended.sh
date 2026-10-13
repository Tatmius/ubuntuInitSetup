# shellcheck shell=bash
# Step 8: unattended-upgrades: install security and normal updates daily,
# never reboot automatically.

step_unattended() {
  if [[ $SETUP_UNATTENDED_UPGRADES != yes ]]; then
    say "== unattended-upgrades skipped (--no-unattended)"
    return 0
  fi
  say "== unattended-upgrades"
  local new_file
  new_file=$(mktemp)

  cat > "$new_file" <<'CONF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Unattended-Upgrade "1";
CONF
  install_file_if_changed "$new_file" /etc/apt/apt.conf.d/20auto-upgrades 0644 root root

  cat > "$new_file" <<'CONF'
Unattended-Upgrade::Allowed-Origins {
        "${distro_id}:${distro_codename}-security";
        "${distro_id}:${distro_codename}-updates";
};
Unattended-Upgrade::Mail "root";           // change to an e-mail address if needed
Unattended-Upgrade::MailOnlyOnError "true";
Unattended-Upgrade::Automatic-Reboot "false";
CONF
  install_file_if_changed "$new_file" /etc/apt/apt.conf.d/50unattended-upgrades 0644 root root
  rm -f "$new_file"
}
