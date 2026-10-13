# shellcheck shell=bash
# output.sh - messages, the warning list, and running commands (or only printing
# them when --dry-run is used).

WARNINGS=()

say() {
  printf '[init] %s\n' "$*"
}

# warn: print a warning now and repeat it in the summary at the end.
warn() {
  printf '[init] WARN: %s\n' "$*" >&2
  WARNINGS+=("$*")
}

die() {
  printf '[init] ERROR: %s\n' "$*" >&2
  exit 1
}

is_dry_run() {
  [[ $DRY_RUN == yes ]]
}

# run COMMAND...: run the command; with --dry-run only print it.
run() {
  if is_dry_run; then
    printf '[dry-run] %s\n' "$*"
    return 0
  fi
  "$@"
}

# run_or_warn COMMAND...: like run, but a failure is only a warning.
# Used for things that often fail inside an unprivileged LXC container.
run_or_warn() {
  if ! run "$@"; then
    warn "failed (continuing): $*"
  fi
}

print_warnings() {
  if [[ ${#WARNINGS[@]} -eq 0 ]]; then
    say "no warnings"
    return 0
  fi
  say "${#WARNINGS[@]} warning(s):"
  local warning
  for warning in "${WARNINGS[@]}"; do
    printf '  - %s\n' "$warning"
  done
}
