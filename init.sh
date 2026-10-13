#!/usr/bin/env bash
# init.sh - first-time setup of a fresh Ubuntu server or LXC container. Run as root.
#
# With no options it is interactive, as before: it asks for the sudo user name,
# its password and git user.name / user.email.
# Options add SSH keys, a key-only "operator" user and unattended runs.
# See readme.md or run: ./init.sh --help
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# shellcheck disable=SC1091  # the files below are checked on their own
source "$SCRIPT_DIR/lib/output.sh"    # say, warn, die, run (honours --dry-run)
source "$SCRIPT_DIR/lib/helpers.sh"   # small checks and file helpers
source "$SCRIPT_DIR/lib/options.sh"   # defaults, --help, argument parsing
source "$SCRIPT_DIR/lib/keys.sh"      # collect, validate and install public SSH keys
source "$SCRIPT_DIR/lib/admin.sh"     # the admin (sudo) user and its password
source "$SCRIPT_DIR/lib/operator.sh"  # the key-only operator user
source "$SCRIPT_DIR/lib/sudoers.sh"   # the operator's sudoers file
source "$SCRIPT_DIR/lib/sshd.sh"      # turn off SSH password login
for step_file in "$SCRIPT_DIR"/steps/*.sh; do
  # shellcheck disable=SC1090
  source "$step_file"                 # step_apt, step_locale, step_ufw, ...
done

main() {
  set_defaults
  parse_arguments "$@"
  check_user_name "$OPERATOR_USER"

  if [[ $PRINT_SUDOERS == yes ]]; then
    render_sudoers "$OPERATOR_USER"
    exit 0
  fi

  check_options
  if [[ $DRY_RUN == yes ]]; then
    say "DRY RUN: nothing will be changed"
  fi

  # Read and check all keys first, so bad input stops us before anything changes.
  KEY_DIR=$(mktemp -d)
  trap 'rm -rf "$KEY_DIR"' EXIT
  collect_admin_keys "$KEY_DIR/admin.keys"
  collect_operator_keys "$KEY_DIR/operator.keys"

  # 1-2: system
  step_apt
  step_locale

  # 3: users and SSH
  if [[ -z $ADMIN_USER ]]; then
    ADMIN_USER=$(prompt_username)
    check_user_name "$ADMIN_USER"
  fi
  setup_admin_user "$ADMIN_USER"
  setup_admin_keys "$ADMIN_USER" "$KEY_DIR/admin.keys"
  setup_operator_if_keys_given "$OPERATOR_USER" "$KEY_DIR/operator.keys"
  setup_sshd_password_login "$KEY_DIR/admin.keys"

  # 4-8: firewall, packages, tools
  step_ufw
  step_packages
  step_git
  step_nvim "$ADMIN_USER"
  step_unattended

  say "Setup completed for admin '$ADMIN_USER'."
  say "Start Neovim as $ADMIN_USER and run :PlugInstall once (if Neovim setup was not skipped)."
  print_warnings
}

main "$@"
