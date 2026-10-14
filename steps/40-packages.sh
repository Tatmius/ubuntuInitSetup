# shellcheck shell=bash
# Step 5: base packages.

step_packages() {
  local packages=(git neovim curl build-essential man-db unattended-upgrades apt-listchanges)
  if [[ $INSTALL_FAIL2BAN == yes ]]; then
    packages+=(fail2ban)
  fi
  say "== packages: ${packages[*]}"
  run apt-get install -y "${packages[@]}"
}
