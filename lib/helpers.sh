# shellcheck shell=bash
# helpers.sh - small checks and file helpers used by several steps.

has_terminal() {
  [[ -t 0 && -t 1 ]]
}

# is_interactive: we may ask questions (a terminal, and no --non-interactive).
is_interactive() {
  [[ $NONINTERACTIVE != yes ]] && has_terminal
}

require_root() {
  if [[ $EUID -ne 0 ]] && ! is_dry_run; then
    die "run as root (or try --dry-run)"
  fi
}

# check_user_name NAME: a safe Linux user name (it is also used in file names).
check_user_name() {
  if [[ ! $1 =~ ^[a-z_][a-z0-9_-]{0,31}$ ]]; then
    die "invalid user name: '$1'"
  fi
}

# home_dir_of USER: the user's home directory, or /home/USER if the user does
# not exist yet (for example in --dry-run).
home_dir_of() {
  local user=$1
  local home
  home=$(getent passwd "$user" | cut -d: -f6 || true)
  if [[ -z $home ]]; then
    home=/home/$user
  fi
  echo "$home"
}

# install_file_if_changed SOURCE DEST MODE OWNER GROUP
# Copy SOURCE to DEST only when the content differs, so re-runs change nothing.
install_file_if_changed() {
  local source=$1 dest=$2 mode=$3 owner=$4 group=$5
  if [[ -f $dest ]] && cmp -s "$source" "$dest" 2>/dev/null; then
    say "unchanged: $dest"
    return 0
  fi
  run install -m "$mode" -o "$owner" -g "$group" "$source" "$dest"
  if is_dry_run; then
    say "would write: $dest"
  else
    say "written: $dest"
  fi
}
