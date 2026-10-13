## how to use
1. clone this repository using git
2. set execute permittion like "chmod u+x fileName"
3. run `sudo ./init.sh` (interactive, same as before), or see the options below

## options (all optional)
Nothing personal is stored in this repository: user names, public keys and passwords
are passed in when you run it. `./init.sh --help` lists every option.

```bash
# unattended: admin with SSH keys + a narrow key-only operator user
sudo ./init.sh --non-interactive \
  --admin-user <name> --admin-key-url https://github.com/<github-user>.keys \
  --operator-key-file /path/to/operator.pub \
  --admin-password-file /root/admin.pw      # first line = password; delete the file afterwards
```

- **Keys**: `--admin-key/--admin-key-file/--admin-key-url` and the same for `--operator-*`
  (repeatable; public keys only, validated with `ssh-keygen -lf`). Admin keys are merged into
  `authorized_keys`; operator keys replace it.
- **Admin password**: never on the command line. `prompt` (hidden input, default with a terminal),
  `generate` (random, shown once on the terminal), `--admin-password-file PATH`, or `lock`
  (default without a terminal). An existing password is never changed.
- **Operator** (default `llm-operator`): created only when it gets a key; password locked,
  never in `sudo`/`adm`. `/etc/sudoers.d/<operator>` comes from `templates/sudoers-operator`
  (apt-get update/upgrade/autoremove/clean, journalctl vacuum only), checked with `visudo -cf`
  before it is installed. Add host rules with `--sudoers-extra FILE`; `--print-sudoers` shows it.
- **SSH**: when admin keys are given, password login is turned off
  (`/etc/ssh/sshd_config.d/10-ubuntu-init-keys-only.conf`); `--keep-ssh-passwords` to skip.
- **LXC**: ufw and timedatectl failures are warnings, not fatal; `--no-ufw` uses the Proxmox firewall.
- **Safe to re-run**: every step checks the current state first. `--dry-run` shows what would change.

## layout
`init.sh` (options + order) · `lib/` (helpers, keys, users, sudoers, sshd) ·
`steps/` (system, firewall, packages, git, nvim, unattended-upgrades) · `templates/`
