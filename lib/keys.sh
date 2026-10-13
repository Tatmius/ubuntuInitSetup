# shellcheck shell=bash
# Public SSH keys: collect from strings / files / URLs, validate, write authorized_keys.

# collect_keys OUT STRINGS FILES URLS  (each list is newline-separated, may be empty)
collect_keys() {
  local out=$1 strs=$2 files=$3 urls=$4 f u
  : > "$out"
  if [[ -n $strs ]]; then printf '%s\n' "$strs" >> "$out"; fi
  while IFS= read -r f; do
    [[ -z $f ]] && continue
    [[ -r $f ]] || die "key file not readable: $f"
    cat "$f" >> "$out"; echo >> "$out"
  done <<< "$files"
  while IFS= read -r u; do
    [[ -z $u ]] && continue
    curl -fsSL --max-time 20 "$u" >> "$out" || die "cannot fetch keys from $u"
    echo >> "$out"
  done <<< "$urls"
  validate_keys "$out"
}

# validate_keys FILE: keep valid public key lines (deduplicated); refuse private keys.
validate_keys() {
  local file=$1 tmp one line n=0
  if grep -q 'PRIVATE KEY' "$file"; then die "a PRIVATE key was given; pass public keys only"; fi
  tmp=$(mktemp); one=$(mktemp)
  while IFS= read -r line || [[ -n $line ]]; do
    line=${line%$'\r'}
    [[ -z ${line// /} || $line == \#* ]] && continue
    printf '%s\n' "$line" > "$one"
    if command -v ssh-keygen >/dev/null; then
      ssh-keygen -lf "$one" >/dev/null 2>&1 || die "invalid public key: ${line:0:30}..."
    elif ! [[ $line =~ (^|[[:space:]])(ssh-|ecdsa-|sk-) ]]; then
      die "invalid public key: ${line:0:30}..."
    fi
    if ! grep -qxF "$line" "$tmp"; then printf '%s\n' "$line" >> "$tmp"; n=$((n + 1)); fi
  done < "$file"
  mv "$tmp" "$file"; rm -f "$one"
  say "$(basename "$file"): $n valid public key(s)"
}

# write_keys USER KEYFILE MODE: exact = authorized_keys is exactly KEYFILE,
#                              merge = add missing keys, keep existing ones.
write_keys() {
  local user=$1 keys=$2 mode=$3 home ak tmp line
  home=$(home_of "$user"); ak=$home/.ssh/authorized_keys
  tmp=$(mktemp)
  if [[ $mode == merge && -r $ak ]]; then cat "$ak" > "$tmp"; fi
  while IFS= read -r line; do
    grep -qxF "$line" "$tmp" || printf '%s\n' "$line" >> "$tmp"
  done < "$keys"
  run install -d -m 0700 -o "$user" -g "$user" "$home/.ssh"
  install_if_changed "$tmp" "$ak" 0600 "$user:$user"
  rm -f "$tmp"
}
