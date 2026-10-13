# shellcheck shell=bash
# Steps 1-2: package upgrade, timezone and locale.

step_apt() {
  [[ $DO_APT == 1 ]] || { say "== apt upgrade skipped (--no-apt-upgrade)"; return 0; }
  say "== apt update / upgrade"
  run apt-get update
  run apt-get -y -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold upgrade
  run apt-get -y autoremove
  run apt-get clean
}

step_locale() {
  say "== timezone $TIMEZONE, locale $LOCALE"
  if ! run timedatectl set-timezone "$TIMEZONE"; then
    warn "timedatectl failed (common in LXC); linked /etc/localtime instead"
    try ln -sf "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime
    dry || echo "$TIMEZONE" > /etc/timezone
  fi
  command -v locale-gen >/dev/null || try apt-get install -y locales
  try locale-gen "$LOCALE"
  try update-locale "LANG=$LOCALE"
}
