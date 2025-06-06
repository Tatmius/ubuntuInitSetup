#!/usr/bin/env bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 1) 基本パッケージ更新
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
apt update
apt upgrade -y
apt autoremove -y
apt clean

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 2) タイムゾーン＆ロケール設定
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
timedatectl set-timezone Asia/Tokyo
locale-gen en_US.UTF-8
update-locale LANG=en_US.UTF-8

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 3) ユーザー作成（sudo 権限付与）
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
prompt_username() {
  local name=""
  while [[ -z "${name// /}" ]]; do
    read -rp "Enter new sudo user name: " name
    if [[ -z "${name// /}" ]]; then
      echo "ユーザー名は空白不可です。再度入力してください。"
    fi
  done
  echo "$name"
}

FIRST_USER_NAME=$(prompt_username)
adduser "$FIRST_USER_NAME"
usermod -aG sudo "$FIRST_USER_NAME"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 4) UFW 設定
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw --force enable
ufw status verbose

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 5) 必要パッケージインストール
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
apt install -y \
  git \
  neovim \
  curl \
  build-essential \
  man-db \
  unattended-upgrades \
  apt-listchanges \
  fail2ban

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 6) Git の初期設定：main 固定
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
git config --global init.defaultBranch main

read -rp "Enter git user.name: " GIT_USER_NAME
git config --global user.name "$GIT_USER_NAME"

read -rp "Enter git user.email: " GIT_USER_EMAIL
git config --global user.email "$GIT_USER_EMAIL"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 7) Neovim プラグインマネージャー（vim-plug）をインストール
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
runuser -l "$FIRST_USER_NAME" -c 'mkdir -p ~/.local/share/nvim/site/autoload'
runuser -l "$FIRST_USER_NAME" -c 'curl -fLo ~/.local/share/nvim/site/autoload/plug.vim --create-dirs \
    https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim'

NVIM_CONFIG_DIR="/home/$FIRST_USER_NAME/.config/nvim"
runuser -l "$FIRST_USER_NAME" -c "mkdir -p $NVIM_CONFIG_DIR"
if [[ -f "./init.vim" ]]; then
  mv "./init.vim" "$NVIM_CONFIG_DIR/init.vim"
  chown "$FIRST_USER_NAME":"$FIRST_USER_NAME" "$NVIM_CONFIG_DIR/init.vim"
fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 8) unattended-upgrades 設定（自動アップデート有効化）
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# 8-1) /etc/apt/apt.conf.d/20auto-upgrades を上書き
cat << 'EOF' > /etc/apt/apt.conf.d/20auto-upgrades
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Unattended-Upgrade "1";
EOF

# 8-2) /etc/apt/apt.conf.d/50unattended-upgrades の "Allowed-Origins" を必要に応じて有効化
# ここではセキュリティ + 標準更新も自動適用する例を示す
cat << 'EOF' > /etc/apt/apt.conf.d/50unattended-upgrades
Unattended-Upgrade::Allowed-Origins {
        "${distro_id}:${distro_codename}-security";
        "${distro_id}:${distro_codename}-updates";
};
Unattended-Upgrade::Mail "root";           # 必要ならメールアドレスに変更
Unattended-Upgrade::MailOnlyOnError "true";
Unattended-Upgrade::Automatic-Reboot "false";  # 再起動も一切したくなければ false
EOF

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 9) Fail2Ban の簡易設定（必要なら細かく編集）
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# (例: /etc/fail2ban/jail.local をテンプレートからコピーするなど)

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 完了メッセージ
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo "Setup completed."
echo "・Git のデフォルトブランチはすでに main に固定されています。"
echo "・自動アップデート (unattended-upgrades) を有効化しました。"
echo "・必要に応じて /etc/apt/apt.conf.d/50unattended-upgrades を編集してください。"
echo "・Neovim を起動して :PlugInstall を実行してください。"
