#!/usr/bin/env bash
# shellcheck disable=SC2034  # variables are used by the sourced lib/ and steps/ files
# init.sh: first-time setup of a fresh Ubuntu server or LXC container. Run as root.
# Without options it is interactive, as before: it asks for the sudo user name, its
# password and git user.name/email. Options allow SSH keys, a narrow key-only operator
# user and fully unattended runs. See readme.md or ./init.sh --help.
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
INIT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# Defaults; every value can also come from the INIT_* environment variable.
ADMIN_USER=${INIT_ADMIN_USER:-}
ADMIN_KEYS=${INIT_ADMIN_KEYS:-} ADMIN_KEY_FILES=${INIT_ADMIN_KEY_FILE:-} ADMIN_KEY_URLS=${INIT_ADMIN_KEY_URL:-}
OPERATOR_USER=${INIT_OPERATOR_USER:-llm-operator}
OPERATOR_KEYS=${INIT_OPERATOR_KEYS:-} OPERATOR_KEY_FILES=${INIT_OPERATOR_KEY_FILE:-}
OPERATOR_KEY_URLS=${INIT_OPERATOR_KEY_URL:-}
ADMIN_PW_MODE=${INIT_ADMIN_PW_MODE:-} ADMIN_PW_FILE=${INIT_ADMIN_PW_FILE:-}
GIT_NAME=${INIT_GIT_NAME:-} GIT_EMAIL=${INIT_GIT_EMAIL:-}
TIMEZONE=${INIT_TIMEZONE:-Asia/Tokyo} LOCALE=${INIT_LOCALE:-en_US.UTF-8}
SSH_KEYS_ONLY=${INIT_SSH_KEYS_ONLY:-auto} SUDOERS_EXTRA=${INIT_SUDOERS_EXTRA:-}
NONINTERACTIVE=${INIT_NONINTERACTIVE:-0} DRY_RUN=0 PRINT_SUDOERS=0
DO_APT=1 DO_UFW=1 DO_FAIL2BAN=1 DO_NVIM=1 DO_UNATTENDED=1

for f in "$INIT_DIR"/lib/*.sh "$INIT_DIR"/steps/*.sh; do
  # shellcheck source=/dev/null
  source "$f"
done

usage() {
  cat <<'TXT'
Usage: sudo ./init.sh [options]          (no options = interactive, as before)
Users and keys (KEY options may be repeated; keys are PUBLIC keys):
  --admin-user NAME             sudo user to create (asked if omitted and interactive)
  --admin-key KEY | --admin-key-file PATH | --admin-key-url URL  (e.g. https://github.com/<user>.keys)
  --operator-user NAME          key-only operator (default llm-operator); created only if it gets a key
  --operator-key KEY | --operator-key-file PATH | --operator-key-url URL
  --sudoers-extra FILE          extra operator sudoers rules (@OPERATOR@ is replaced)
Admin password (never passed on the command line):
  --admin-password-mode prompt|generate|lock   prompt = hidden input (default with a terminal),
                                generate = random, shown once on the terminal, lock = none
  --admin-password-file PATH    read it from the first line of PATH (for unattended runs)
SSH:  --ssh-keys-only | --keep-ssh-passwords  (default: password login off when admin keys are given)
System: --timezone TZ (Asia/Tokyo)  --locale L (en_US.UTF-8)  --git-name N  --git-email E
Skip:   --no-apt-upgrade --no-ufw --no-fail2ban --no-nvim --no-unattended
Modes:  --non-interactive  never prompt   --dry-run  print what would change   --print-sudoers
TXT
}

while [[ $# -gt 0 ]]; do
  case $1 in
    --admin-user) ADMIN_USER=${2:?}; shift ;;
    --admin-key) add ADMIN_KEYS "${2:?}"; shift ;;
    --admin-key-file) add ADMIN_KEY_FILES "${2:?}"; shift ;;
    --admin-key-url) add ADMIN_KEY_URLS "${2:?}"; shift ;;
    --operator-user) OPERATOR_USER=${2:?}; shift ;;
    --operator-key) add OPERATOR_KEYS "${2:?}"; shift ;;
    --operator-key-file) add OPERATOR_KEY_FILES "${2:?}"; shift ;;
    --operator-key-url) add OPERATOR_KEY_URLS "${2:?}"; shift ;;
    --sudoers-extra) SUDOERS_EXTRA=${2:?}; shift ;;
    --admin-password-mode) ADMIN_PW_MODE=${2:?}; shift ;;
    --admin-password-file) ADMIN_PW_FILE=${2:?}; ADMIN_PW_MODE="file"; shift ;;
    --ssh-keys-only) SSH_KEYS_ONLY=yes ;;
    --keep-ssh-passwords) SSH_KEYS_ONLY=no ;;
    --timezone) TIMEZONE=${2:?}; shift ;;
    --locale) LOCALE=${2:?}; shift ;;
    --git-name) GIT_NAME=${2:?}; shift ;;
    --git-email) GIT_EMAIL=${2:?}; shift ;;
    --no-apt-upgrade) DO_APT=0 ;;
    --no-ufw) DO_UFW=0 ;;
    --no-fail2ban) DO_FAIL2BAN=0 ;;
    --no-nvim) DO_NVIM=0 ;;
    --no-unattended) DO_UNATTENDED=0 ;;
    --non-interactive) NONINTERACTIVE=1 ;;
    --dry-run) DRY_RUN=1 ;;
    --print-sudoers) PRINT_SUDOERS=1 ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown option: $1 (see --help)" ;;
  esac
  shift
done

valid_name "$OPERATOR_USER"
if [[ $PRINT_SUDOERS == 1 ]]; then render_sudoers "$OPERATOR_USER"; exit 0; fi
need_root
if [[ -z $ADMIN_PW_MODE ]]; then
  if interactive; then ADMIN_PW_MODE=prompt; else ADMIN_PW_MODE=lock; fi
fi
if [[ -z $ADMIN_USER ]] && ! interactive; then die "--admin-user is required without a terminal"; fi
if [[ -n $ADMIN_USER ]]; then valid_name "$ADMIN_USER"; fi
[[ $ADMIN_USER != "$OPERATOR_USER" ]] || die "admin and operator must be different users"
dry && say "DRY RUN: nothing will be changed"

# Collect and validate keys first, so bad input fails before anything changes.
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
collect_keys "$WORK/admin.keys" "$ADMIN_KEYS" "$ADMIN_KEY_FILES" "$ADMIN_KEY_URLS"
collect_keys "$WORK/operator.keys" "$OPERATOR_KEYS" "$OPERATOR_KEY_FILES" "$OPERATOR_KEY_URLS"

step_apt
step_locale
if [[ -z $ADMIN_USER ]]; then ADMIN_USER=$(prompt_username); valid_name "$ADMIN_USER"; fi
ensure_admin "$ADMIN_USER"
if [[ -s $WORK/admin.keys ]]; then
  write_keys "$ADMIN_USER" "$WORK/admin.keys" merge
else
  say "no admin keys given: SSH key setup for $ADMIN_USER skipped"
fi
if [[ -s $WORK/operator.keys ]]; then
  ensure_operator "$OPERATOR_USER" "$WORK/operator.keys"
else
  say "no operator keys given: operator user not created"
fi
case $SSH_KEYS_ONLY in
  yes) sshd_keys_only ;;
  auto) if [[ -s $WORK/admin.keys ]]; then sshd_keys_only; else say "sshd unchanged (no admin keys)"; fi ;;
  no) say "sshd unchanged (--keep-ssh-passwords)" ;;
esac
step_ufw
step_packages
step_git
step_nvim "$ADMIN_USER"
step_unattended

say "Setup completed for admin '$ADMIN_USER'."
say "Start Neovim as $ADMIN_USER and run :PlugInstall once (if Neovim setup was not skipped)."
print_warnings
