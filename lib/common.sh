# shellcheck shell=bash
# Common helpers: logging, dry-run aware execution, small checks.

WARNINGS=()
say()  { printf '[init] %s\n' "$*"; }
warn() { printf '[init] WARN: %s\n' "$*" >&2; WARNINGS+=("$*"); }
die()  { printf '[init] ERROR: %s\n' "$*" >&2; exit 1; }
dry()  { [[ ${DRY_RUN:-0} == 1 ]]; }

# run CMD...: execute it, or only print it in --dry-run mode.
run() {
  if dry; then printf '[dry-run] %s\n' "$*"; return 0; fi
  "$@"
}

# try CMD...: like run, but a failure is only a warning (unprivileged LXC quirks).
try() { run "$@" || warn "failed (continuing): $*"; }

has_tty()     { [[ -t 0 && -t 1 ]]; }
interactive() { [[ ${NONINTERACTIVE:-0} != 1 ]] && has_tty; }
need_root()   { [[ $EUID -eq 0 ]] || dry || die "run as root (or try --dry-run)"; }

# valid_name NAME: a safe Linux user name (also used in file names and sed).
valid_name() { [[ $1 =~ ^[a-z_][a-z0-9_-]{0,31}$ ]] || die "invalid user name: '$1'"; }

# home_of USER: home directory (falls back to /home/USER, e.g. in --dry-run).
home_of() {
  local h
  h=$(getent passwd "$1" | cut -d: -f6 || true)
  printf '%s\n' "${h:-/home/$1}"
}

# install_if_changed SRC DEST MODE OWNER:GROUP: install only when the content differs.
install_if_changed() {
  local src=$1 dest=$2 mode=$3 owner=$4
  if [[ -f $dest ]] && cmp -s "$src" "$dest" 2>/dev/null; then
    say "unchanged: $dest"
    return 0
  fi
  run install -m "$mode" -o "${owner%%:*}" -g "${owner##*:}" "$src" "$dest"
  if dry; then say "would write: $dest"; else say "written: $dest"; fi
}

# add VAR LINE: append LINE to the newline-separated list in VAR.
add() { printf -v "$1" '%s%s%s' "${!1}" "${!1:+$'\n'}" "$2"; }

print_warnings() {
  [[ ${#WARNINGS[@]} -eq 0 ]] && { say "no warnings"; return 0; }
  say "${#WARNINGS[@]} warning(s):"
  local w; for w in "${WARNINGS[@]}"; do printf '  - %s\n' "$w"; done
}
