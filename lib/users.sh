# shellcheck shell=bash
# The admin (sudo) user and the narrow, key-only operator user.

user_exists() { id "$1" >/dev/null 2>&1; }
# pw_status USER: P = usable password, L = locked, NP = empty (see passwd -S).
pw_status() { passwd -S "$1" 2>/dev/null | awk '{print $2}'; }

prompt_username() {
  local name=""
  while [[ -z ${name// /} ]]; do
    read -rp "Enter new sudo user name: " name
    if [[ -z ${name// /} ]]; then echo "User name must not be empty. Please try again." >&2; fi
  done
  printf '%s\n' "$name"
}

# chpw USER PASSWORD: via stdin only; never on a command line or in output.
chpw() {
  if dry; then say "[dry-run] chpasswd for $1 (password hidden)"; return 0; fi
  printf '%s:%s\n' "$1" "$2" | chpasswd
}

# read_hidden VAR: ask twice without echo.
read_hidden() {
  local a b
  while :; do
    read -rsp "New password for the admin user: " a; echo
    read -rsp "Retype: " b; echo
    [[ $a == "$b" && ${#a} -ge 8 ]] && break
    echo "Passwords differ or are shorter than 8 characters." >&2
  done
  printf -v "$1" '%s' "$a"
}

# ensure_admin NAME: create the sudo user if missing, then set its password (once).
ensure_admin() {
  local name=$1
  say "== admin user $name"
  if user_exists "$name"; then
    say "user $name exists"
  elif [[ $ADMIN_PW_MODE == prompt ]] && interactive; then
    run adduser "$name"        # interactive, asks for the password (original behaviour)
  else
    run adduser --disabled-password --gecos "" "$name"
  fi
  run usermod -aG sudo "$name"
  set_admin_password "$name"
}

# set_admin_password NAME: only if the account has no usable password yet (idempotent).
set_admin_password() {
  local name=$1 pw=""
  if [[ $(pw_status "$name") == P ]]; then say "password already set (unchanged)"; return 0; fi
  case $ADMIN_PW_MODE in
    file)
      [[ -r $ADMIN_PW_FILE ]] || die "--admin-password-file is not readable"
      IFS= read -r pw < "$ADMIN_PW_FILE" || true
      pw=${pw%$'\r'}
      [[ ${#pw} -ge 8 ]] || die "password in --admin-password-file is shorter than 8 characters"
      chpw "$name" "$pw"; say "password set from file" ;;
    generate)
      if dry; then say "[dry-run] would generate a password and show it once"; return 0; fi
      [[ -w /dev/tty ]] || die "--admin-password-mode generate needs a terminal (shown once there)"
      pw=$(openssl rand -base64 18 | tr -d '\n')
      chpw "$name" "$pw"
      printf '\n  Password for %s (shown ONCE, store it now): %s\n\n' "$name" "$pw" > /dev/tty ;;
    prompt)
      interactive || die "no terminal: use --admin-password-file FILE or --admin-password-mode lock"
      read_hidden pw; chpw "$name" "$pw"; say "password set" ;;
    lock)
      run usermod -L "$name"
      warn "$name has no password (locked): sudo will ask for one that does not exist; set it with passwd" ;;
    *) die "unknown --admin-password-mode: $ADMIN_PW_MODE" ;;
  esac
  pw=""
}

# ensure_operator NAME KEYFILE: key-only login, password locked, never in sudo/adm.
ensure_operator() {
  local name=$1 keys=$2 g
  say "== operator user $name"
  if user_exists "$name"; then
    say "user $name exists"
  else
    run useradd --create-home --shell /bin/bash --comment "automation operator" "$name"
  fi
  run usermod --shell /bin/bash -L "$name"
  for g in sudo adm; do
    if id -nG "$name" 2>/dev/null | tr ' ' '\n' | grep -qx "$g"; then run gpasswd -d "$name" "$g"; fi
  done
  write_keys "$name" "$keys" exact
  install_operator_sudoers "$name"
}
