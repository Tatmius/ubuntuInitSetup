# shellcheck shell=bash
# Step 7: Neovim for the admin user: the vim-plug plugin manager and init.vim.
# init.vim is copied (not moved), so the clone stays clean and re-runs work.

VIM_PLUG_URL=https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim

step_nvim() {
  local user=$1
  local home plug_file
  if [[ $SETUP_NEOVIM != yes ]]; then
    say "== neovim setup skipped (--no-nvim)"
    return 0
  fi
  say "== neovim: vim-plug + init.vim for $user"
  home=$(home_dir_of "$user")
  plug_file=$home/.local/share/nvim/site/autoload/plug.vim

  run runuser -u "$user" -- mkdir -p "$(dirname "$plug_file")" "$home/.config/nvim"
  if [[ -s $plug_file ]]; then
    say "vim-plug already present"
  else
    run_or_warn runuser -u "$user" -- curl -fsSLo "$plug_file" "$VIM_PLUG_URL"
  fi
  if [[ -f $SCRIPT_DIR/init.vim ]]; then
    install_file_if_changed "$SCRIPT_DIR/init.vim" "$home/.config/nvim/init.vim" 0644 "$user" "$user"
  fi
}
