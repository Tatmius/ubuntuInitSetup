# shellcheck shell=bash
# Step 5: base packages.

step_packages() {
  local pkgs=(git neovim curl build-essential man-db unattended-upgrades apt-listchanges)
  [[ $DO_FAIL2BAN == 1 ]] && pkgs+=(fail2ban)
  say "== packages: ${pkgs[*]}"
  run apt-get install -y "${pkgs[@]}"
}
