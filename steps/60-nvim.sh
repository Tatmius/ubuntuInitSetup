# shellcheck shell=bash
# Step 7: vim-plug and init.vim for the admin user. init.vim is copied, not moved,
# so the clone stays clean and re-runs work.

PLUG_URL=https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim

step_nvim() {
  local user=$1 home plug
  [[ $DO_NVIM == 1 ]] || { say "== neovim setup skipped (--no-nvim)"; return 0; }
  say "== neovim: vim-plug + init.vim for $user"
  home=$(home_of "$user"); plug=$home/.local/share/nvim/site/autoload/plug.vim
  run runuser -u "$user" -- mkdir -p "$(dirname "$plug")" "$home/.config/nvim"
  if [[ -s $plug ]]; then
    say "vim-plug already present"
  else
    try runuser -u "$user" -- curl -fsSLo "$plug" "$PLUG_URL"
  fi
  if [[ -f $INIT_DIR/init.vim ]]; then
    install_if_changed "$INIT_DIR/init.vim" "$home/.config/nvim/init.vim" 0644 "$user:$user"
  fi
}
