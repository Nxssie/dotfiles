# dotfiles

Nxssie's Arch + Hyprland desktop — the stable system definition.

Wayland compositor (Hyprland, Lua config), custom Quickshell bar (network,
battery, power menu, launcher, bindings help, dark/light theme toggle wired
into hyprlock + ghostty + KDE color schemes), fish, ghostty, mise.

## Layout

```
├── install.sh            # idempotent bootstrap (symlinks + backups)
├── config/
│   ├── hypr/             # hyprland.lua, hypridle, hyprlock theme template, lock.sh
│   ├── quickshell/       # the whole bar/shell (QML)
│   ├── fish/             # shell config (secrets.fish gitignored)
│   ├── ghostty/          # terminal + custom CreamyForest light theme
│   ├── zed/              # editor settings
│   ├── ssh/config        # ~/.ssh/config — git.nxssie.dev on port 2222
│   ├── kdeglobals        # KDE color scheme selection (Tokyo Night)
│   └── color-schemes/    # Tokyo Night dark/light → ~/.local/share/color-schemes
├── assets/wallpapers/    # dark.png / light.png → ~/Pictures/Wallpapers
├── packages/             # pacman.txt (explicit native), aur.txt (foreign)
└── system/sddm/          # /etc/sddm.conf.d/theme.conf (pixie theme)
```

## Fresh install

```fish
git clone git@github.com:Nxssie/dotfiles.git ~/Projects/nxssie/dotfiles
cd ~/Projects/nxssie/dotfiles
./install.sh
```

`install.sh` is idempotent: it symlinks whole config dirs (stow semantics,
no stow), backs up anything it replaces as `<target>.bak.<timestamp>`, seeds
`secrets.fish` from the committed template if missing, and enables the
socket-activated `ssh-agent.socket` user unit.

## Updating after a change

Edit the files directly under `~/Projects/nxssie/dotfiles` (they ARE the live
config via symlinks), then commit and push:

```fish
cd ~/Projects/nxssie/dotfiles
git add -A && git commit -m "feat(quickshell): ..." && git push
```

Refresh package lists after installing/removing packages:

```fish
pacman -Qqen > packages/pacman.txt
pacman -Qqm | grep -v paru-debug > packages/aur.txt
```

## Not managed here (on purpose)

- **mise** (`~/.config/mise/config.toml`) — symlinked from
  [harnxss](https://github.com/Nxssie/harnxss), the AI-tooling hub.
- **pixie-sddm** — unmodified upstream clone; installed to
  `/usr/share/sddm/themes/pixie` (see manual steps in `install.sh`).
- **Secrets** — only `conf.d/secrets.fish.example` is committed; the real
  `secrets.fish` is gitignored.
- SSH keys (`~/.ssh/id_*`, `known_hosts`) stay untracked; only the host
  config is managed.
- Machine state (`~/.config/session`, `trashrc`, dolphin/mime caches, app
  data like helium/Bitwarden).

## Mirrors

- GitHub (origin): `git@github.com:Nxssie/dotfiles.git`
- Gitea (self-hosted): `gitea` remote — `ssh://git@git.nxssie.dev/nxssie/dotfiles.git`
  (SSH on port 2222 via `~/.ssh/config`). Sync with `git push gitea main`.
