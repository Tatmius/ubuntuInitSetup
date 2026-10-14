# shellcheck shell=bash
# admin.sh - the admin (sudo) user: create it, add it to "sudo", set its password
# once, and install its SSH keys.

prompt_username() {
  local name=""
  while [[ $name =~ ^\ *$ ]]; do          # empty or only spaces: ask again
    read -rp "Enter new sudo user name: " name
    if [[ $name =~ ^\ *$ ]]; then
      echo "User name must not be empty. Please try again." >&2
    fi
  done
  echo "$name"
}

setup_admin_user() {
  local name=$1
  say "== admin user $name"
  if id "$name" >/dev/null 2>&1; then
    say "user $name exists"
  elif [[ $ADMIN_PASSWORD_MODE == prompt ]] && is_interactive; then
    run adduser "$name"                    # interactive: asks for the password, as before
  else
    run adduser --disabled-password --gecos "" "$name"
  fi
  run usermod -aG sudo "$name"
  set_admin_password "$name"
}

setup_admin_keys() {
  local name=$1 key_file=$2
  if [[ -s $key_file ]]; then
    install_authorized_keys "$name" "$key_file" add
  else
    say "no admin keys given: SSH key setup for $name skipped"
  fi
}

# set_admin_password NAME: only if the account has no usable password yet,
# so a re-run never changes a password.
set_admin_password() {
  local name=$1 status
  # passwd -S prints e.g. "alice P ...": P = has a password, L = locked. Fails if no such user.
  status=$(passwd -S "$name" 2>/dev/null | awk '{print $2}' || true)
  if [[ $status == P ]]; then
    say "password already set (unchanged)"
    return 0
  fi
  case $ADMIN_PASSWORD_MODE in
    file)     set_password_from_file "$name" ;;
    generate) set_generated_password "$name" ;;
    prompt)   set_prompted_password "$name" ;;
    lock)
      run usermod -L "$name"
      warn "$name has no password (locked): sudo will ask for one that does not exist; set it with passwd"
      ;;
    *) die "unknown --admin-password-mode: $ADMIN_PASSWORD_MODE" ;;
  esac
}

set_password_from_file() {
  local name=$1 password=""
  if [[ ! -r $ADMIN_PASSWORD_FILE ]]; then
    die "--admin-password-file is not readable"
  fi
  IFS= read -r password < "$ADMIN_PASSWORD_FILE" || true   # first line; may lack a newline
  password=${password%$'\r'}
  if [[ ${#password} -lt 8 ]]; then
    die "password in --admin-password-file is shorter than 8 characters"
  fi
  change_password "$name" "$password"
  say "password set from file"
}

set_generated_password() {
  local name=$1 password
  if is_dry_run; then
    say "[dry-run] would generate a password and show it once"
    return 0
  fi
  if [[ ! -w /dev/tty ]]; then
    die "--admin-password-mode generate needs a terminal (shown once there)"
  fi
  password=$(openssl rand -base64 18 | tr -d '\n')
  change_password "$name" "$password"
  # Shown on the terminal only, never in stdout/logs.
  printf '\n  Password for %s (shown ONCE, store it now): %s\n\n' "$name" "$password" > /dev/tty
}

set_prompted_password() {
  local name=$1 first second
  if ! is_interactive; then
    die "no terminal: use --admin-password-file FILE or --admin-password-mode lock"
  fi
  while true; do
    read -rsp "New password for the admin user: " first; echo
    read -rsp "Retype: " second; echo
    if [[ $first == "$second" && ${#first} -ge 8 ]]; then
      break
    fi
    echo "Passwords differ or are shorter than 8 characters." >&2
  done
  change_password "$name" "$first"
  say "password set"
}

# change_password USER PASSWORD: through stdin, never on a command line or in output.
change_password() {
  if is_dry_run; then
    say "[dry-run] chpasswd for $1 (password hidden)"
    return 0
  fi
  printf '%s:%s\n' "$1" "$2" | chpasswd
}
