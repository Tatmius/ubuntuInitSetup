# shellcheck shell=bash
# keys.sh - public SSH keys: collect them from texts, files and URLs into one
# file, check that every line is a valid public key, and install authorized_keys.

collect_admin_keys() {
  local key_file=$1
  : > "$key_file"
  add_key_texts "$key_file" "${ADMIN_KEY_TEXTS[@]}"
  add_key_files "$key_file" "${ADMIN_KEY_FILES[@]}"
  add_key_urls "$key_file" "${ADMIN_KEY_URLS[@]}"
  keep_only_valid_keys "$key_file"
}

collect_operator_keys() {
  local key_file=$1
  : > "$key_file"
  add_key_texts "$key_file" "${OPERATOR_KEY_TEXTS[@]}"
  add_key_files "$key_file" "${OPERATOR_KEY_FILES[@]}"
  add_key_urls "$key_file" "${OPERATOR_KEY_URLS[@]}"
  keep_only_valid_keys "$key_file"
}

# add_key_texts KEY_FILE TEXT...: append key texts given on the command line.
add_key_texts() {
  local key_file=$1 text
  shift
  for text in "$@"; do
    echo "$text" >> "$key_file"
  done
}

add_key_files() {
  local key_file=$1 path
  shift
  for path in "$@"; do
    if [[ ! -r $path ]]; then
      die "key file not readable: $path"
    fi
    cat "$path" >> "$key_file"
    echo >> "$key_file"
  done
}

# add_key_urls KEY_FILE URL...: e.g. https://github.com/<user>.keys
add_key_urls() {
  local key_file=$1 url
  shift
  for url in "$@"; do
    if ! curl -fsSL --max-time 20 "$url" >> "$key_file"; then
      die "cannot fetch keys from $url"
    fi
    echo >> "$key_file"
  done
}

# keep_only_valid_keys KEY_FILE: rewrite the file with each valid key once.
# Blank lines and comments are dropped; anything else that is not a public key stops the script.
keep_only_valid_keys() {
  local key_file=$1
  local checked_keys line count=0
  if grep -q 'PRIVATE KEY' "$key_file"; then
    die "a PRIVATE key was given; pass public keys only"
  fi
  checked_keys=$(mktemp)
  while IFS= read -r line || [[ -n $line ]]; do
    line=${line%$'\r'}                       # files from Windows may end lines with \r
    if [[ $line =~ ^\ *$ || $line == \#* ]]; then
      continue
    fi
    check_public_key "$line"
    if ! grep -qxF "$line" "$checked_keys"; then
      echo "$line" >> "$checked_keys"
      count=$((count + 1))
    fi
  done < "$key_file"
  mv "$checked_keys" "$key_file"
  say "$(basename "$key_file"): $count valid public key(s)"
}

# check_public_key LINE: stop if LINE is not a public key.
check_public_key() {
  local line=$1 one_key_file
  if command -v ssh-keygen >/dev/null; then
    one_key_file=$(mktemp)
    echo "$line" > "$one_key_file"
    if ! ssh-keygen -lf "$one_key_file" >/dev/null 2>&1; then
      rm -f "$one_key_file"
      die "invalid public key: ${line:0:30}..."
    fi
    rm -f "$one_key_file"
  elif [[ ! $line =~ (^|[[:space:]])(ssh-|ecdsa-|sk-) ]]; then
    die "invalid public key: ${line:0:30}..."
  fi
}

# install_authorized_keys USER KEY_FILE MODE
#   MODE=replace: authorized_keys becomes exactly KEY_FILE
#   MODE=add:     keys missing from authorized_keys are added, existing ones are kept
install_authorized_keys() {
  local user=$1 key_file=$2 mode=$3
  local home authorized_keys new_content line
  home=$(home_dir_of "$user")
  authorized_keys=$home/.ssh/authorized_keys
  new_content=$(mktemp)
  if [[ $mode == add && -r $authorized_keys ]]; then
    cat "$authorized_keys" > "$new_content"
  fi
  while IFS= read -r line; do
    if ! grep -qxF "$line" "$new_content"; then
      echo "$line" >> "$new_content"
    fi
  done < "$key_file"
  run install -d -m 0700 -o "$user" -g "$user" "$home/.ssh"
  install_file_if_changed "$new_content" "$authorized_keys" 0600 "$user" "$user"
  rm -f "$new_content"
}
