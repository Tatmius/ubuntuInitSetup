# shellcheck shell=bash
# options.sh - default settings, --help text, and reading the command line.
# Every option can also be given as an INIT_* environment variable.
# shellcheck disable=SC2034  # the variables set here are used by the other files

set_defaults() {
  ADMIN_USER=${INIT_ADMIN_USER:-}
  OPERATOR_USER=${INIT_OPERATOR_USER:-llm-operator}

  # Public keys: lists of key texts, key files and key URLs.
  ADMIN_KEY_TEXTS=() ADMIN_KEY_FILES=() ADMIN_KEY_URLS=()
  OPERATOR_KEY_TEXTS=() OPERATOR_KEY_FILES=() OPERATOR_KEY_URLS=()
  if [[ -n ${INIT_ADMIN_KEYS:-} ]]; then ADMIN_KEY_TEXTS+=("$INIT_ADMIN_KEYS"); fi
  if [[ -n ${INIT_ADMIN_KEY_FILE:-} ]]; then ADMIN_KEY_FILES+=("$INIT_ADMIN_KEY_FILE"); fi
  if [[ -n ${INIT_ADMIN_KEY_URL:-} ]]; then ADMIN_KEY_URLS+=("$INIT_ADMIN_KEY_URL"); fi
  if [[ -n ${INIT_OPERATOR_KEYS:-} ]]; then OPERATOR_KEY_TEXTS+=("$INIT_OPERATOR_KEYS"); fi
  if [[ -n ${INIT_OPERATOR_KEY_FILE:-} ]]; then OPERATOR_KEY_FILES+=("$INIT_OPERATOR_KEY_FILE"); fi
  if [[ -n ${INIT_OPERATOR_KEY_URL:-} ]]; then OPERATOR_KEY_URLS+=("$INIT_OPERATOR_KEY_URL"); fi

  ADMIN_PASSWORD_MODE=${INIT_ADMIN_PW_MODE:-}   # prompt, generate, file or lock
  ADMIN_PASSWORD_FILE=${INIT_ADMIN_PW_FILE:-}
  GIT_NAME=${INIT_GIT_NAME:-}
  GIT_EMAIL=${INIT_GIT_EMAIL:-}
  TIMEZONE=${INIT_TIMEZONE:-Asia/Tokyo}
  LOCALE=${INIT_LOCALE:-en_US.UTF-8}
  SSH_KEYS_ONLY=${INIT_SSH_KEYS_ONLY:-auto}     # auto, yes or no
  SUDOERS_EXTRA=${INIT_SUDOERS_EXTRA:-}

  NONINTERACTIVE=no
  if [[ ${INIT_NONINTERACTIVE:-0} == 1 ]]; then NONINTERACTIVE=yes; fi
  DRY_RUN=no
  PRINT_SUDOERS=no

  RUN_APT_UPGRADE=yes
  SETUP_UFW=yes
  INSTALL_FAIL2BAN=yes
  SETUP_NEOVIM=yes
  SETUP_UNATTENDED_UPGRADES=yes
}

show_help() {
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

# need_value "$@": stop if the current option has no value after it.
need_value() {
  if [[ $# -lt 2 || -z $2 ]]; then
    die "$1 needs a value (see --help)"
  fi
}

parse_arguments() {
  while [[ $# -gt 0 ]]; do
    case $1 in
      --admin-user)          need_value "$@"; ADMIN_USER=$2; shift ;;
      --admin-key)           need_value "$@"; ADMIN_KEY_TEXTS+=("$2"); shift ;;
      --admin-key-file)      need_value "$@"; ADMIN_KEY_FILES+=("$2"); shift ;;
      --admin-key-url)       need_value "$@"; ADMIN_KEY_URLS+=("$2"); shift ;;
      --operator-user)       need_value "$@"; OPERATOR_USER=$2; shift ;;
      --operator-key)        need_value "$@"; OPERATOR_KEY_TEXTS+=("$2"); shift ;;
      --operator-key-file)   need_value "$@"; OPERATOR_KEY_FILES+=("$2"); shift ;;
      --operator-key-url)    need_value "$@"; OPERATOR_KEY_URLS+=("$2"); shift ;;
      --sudoers-extra)       need_value "$@"; SUDOERS_EXTRA=$2; shift ;;
      --admin-password-mode) need_value "$@"; ADMIN_PASSWORD_MODE=$2; shift ;;
      --admin-password-file) need_value "$@"; ADMIN_PASSWORD_FILE=$2; ADMIN_PASSWORD_MODE="file"; shift ;;
      --timezone)            need_value "$@"; TIMEZONE=$2; shift ;;
      --locale)              need_value "$@"; LOCALE=$2; shift ;;
      --git-name)            need_value "$@"; GIT_NAME=$2; shift ;;
      --git-email)           need_value "$@"; GIT_EMAIL=$2; shift ;;
      --ssh-keys-only)       SSH_KEYS_ONLY=yes ;;
      --keep-ssh-passwords)  SSH_KEYS_ONLY=no ;;
      --no-apt-upgrade)      RUN_APT_UPGRADE=no ;;
      --no-ufw)              SETUP_UFW=no ;;
      --no-fail2ban)         INSTALL_FAIL2BAN=no ;;
      --no-nvim)             SETUP_NEOVIM=no ;;
      --no-unattended)       SETUP_UNATTENDED_UPGRADES=no ;;
      --non-interactive)     NONINTERACTIVE=yes ;;
      --dry-run)             DRY_RUN=yes ;;
      --print-sudoers)       PRINT_SUDOERS=yes ;;
      -h|--help)             show_help; exit 0 ;;
      *)                     die "unknown option: $1 (see --help)" ;;
    esac
    shift
  done
}

# check_options: fill in what depends on the terminal and reject bad combinations.
check_options() {
  require_root

  if [[ -z $ADMIN_PASSWORD_MODE ]]; then
    if is_interactive; then
      ADMIN_PASSWORD_MODE=prompt
    else
      ADMIN_PASSWORD_MODE=lock
    fi
  fi

  if [[ -z $ADMIN_USER ]] && ! is_interactive; then
    die "--admin-user is required without a terminal"
  fi
  if [[ -n $ADMIN_USER ]]; then
    check_user_name "$ADMIN_USER"
  fi
  if [[ $ADMIN_USER == "$OPERATOR_USER" ]]; then
    die "admin and operator must be different users"
  fi
}
