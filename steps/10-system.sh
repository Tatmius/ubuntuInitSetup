# shellcheck shell=bash
# Steps 1-2: upgrade packages, then set the timezone and locale.

step_apt() {
  if [[ $RUN_APT_UPGRADE != yes ]]; then
    say "== apt upgrade skipped (--no-apt-upgrade)"
    return 0
  fi
  say "== apt update / upgrade"
  run apt-get update
  # confdef/confold: keep existing config files instead of asking.
  run apt-get -y -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold upgrade
  run apt-get -y autoremove
  run apt-get clean
}

step_locale() {
  say "== timezone $TIMEZONE, locale $LOCALE"
  if ! run timedatectl set-timezone "$TIMEZONE"; then
    warn "timedatectl failed (common in LXC); linked /etc/localtime instead"
    run_or_warn ln -sf "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime
    if ! is_dry_run; then
      echo "$TIMEZONE" > /etc/timezone
    fi
  fi
  if ! command -v locale-gen >/dev/null; then
    run_or_warn apt-get install -y locales
  fi
  run_or_warn locale-gen "$LOCALE"
  run_or_warn update-locale "LANG=$LOCALE"
}
