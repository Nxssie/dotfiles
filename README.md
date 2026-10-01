# dotfiles

Nxssie's Arch desktop — the stable system definition. Daily driver is KDE Plasma
(Wayland); the Hyprland + Quickshell setup is kept as a fallback session.

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
│   ├── plasma/           # Plasma setup: setup.sh, shortcuts*.tsv, panel.js (top bar + dock), tiling.sh, plasmoids/, bin/
│   ├── kdeglobals        # seed only (Hyprland fallback); NOT linked, Plasma owns the live file
│   └── color-schemes/    # Tokyo Night dark/light → ~/.local/share/color-schemes
├── assets/wallpapers/    # dark.png / light.png → ~/Pictures/Wallpapers
├── packages/             # pacman.txt (explicit native), aur.txt (foreign)
└── system/
    ├── sddm/             # /etc/sddm.conf.d/theme.conf (pixie theme)
    └── udev/             # /etc/udev/rules.d — battery charge cap at 80%
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

## Plasma

`config/plasma/` replaces the Hyprland + Quickshell setup. Plasma's own rc files
are *not* symlinked (it rewrites them constantly); `setup.sh` applies the
config instead and is safe to re-run:

```fish
config/plasma/setup.sh            # everything
config/plasma/setup.sh --list     # steps: links workspaces kwin input screen shortcuts power lock spectacle theme panel (+ tiling, opt-in)
config/plasma/setup.sh panel      # just one step
config/plasma/setup.sh tiling     # opt in to Krohnkite auto-tiling; `setup.sh kwin` turns it off again
```

| Hyprland / Quickshell | Plasma |
| --- | --- |
| Bar with chips | top panel (`panel.js`) + `dev.nxssie.claudeusage`, `dev.nxssie.themetoggle` and `dev.nxssie.clock` plasmoids |
| (none, macOS-style dock) | floating bottom panel in `panel.js`: icons-only task manager with the apps pinned in its `launchers` list (Ghostty, Helium, Dolphin, Zed, Bitwarden) |
| Dynamic workspaces (only existing ones shown) | `kwin-scripts/dynamicdesktops`: `Meta+N` creates workspace N on demand, `Meta+Shift+N` sends the window there, empty trailing ones vanish (contiguous 1..N, max 10) |
| Launcher, clipboard, notifications, OSD | KRunner (Meta+Space), Klipper (Meta+Ctrl+V), native notifications/OSD |
| ~80 `hl.bind` bindings, bindings help | `shortcuts.tsv` -> `kglobalshortcutsrc`, `bin/bindings-help` (Meta+K) |
| dwindle auto-tiling | **off by default**: stock floating KWin (titlebars, click to focus, KDE window shortcuts). Opt in with `setup.sh tiling`: Krohnkite, installed from a SHA-256-pinned release (not the AUR package), with its extra keys in `shortcuts-tiling.tsv` |
| hypridle chain, hyprlock | PowerDevil (150/330/900 s) + kscreenlocker (5 min) |
| `Theme.toggle()` | `bin/theme-toggle` (Meta+Shift+T or the panel button) |

Shortcut changes need a re-login to take effect (KWin hosts kglobalacceld). The same
goes for editing `kwin-scripts/dynamicdesktops`: KWin caches a script's QML by path,
so reload it with a log out/in (or load a copy from a new path with
`qdbus6 org.kde.KWin /Scripting loadDeclarativeScript <file> <name>`).

Pin or unpin dock apps by right-clicking them (*Pin to Task Manager*); edit the
`launchers` list in `panel.js` to change the defaults a fresh install gets. The
dock hides while a window overlaps it (`dock.hiding = "dodgewindows"`; `"autohide"`
hides it until the pointer touches the bottom edge, `"none"` keeps it visible);
`dock.height` (40) controls the icon size. Re-run `setup.sh panel` after editing.

The panel clock is `dev.nxssie.clock`, not the stock digital clock: that one's
calendar popup is compiled into the plugin at ~570x460 px and can't be resized.

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
