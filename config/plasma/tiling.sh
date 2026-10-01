# Sourced by setup.sh (step_tiling): installs and configures Krohnkite, the KWin
# auto-tiling script that stands in for Hyprland's dwindle layout.
#
# The release asset is pinned by SHA-256 and installed per-user with
# kpackagetool6 (no sudo, no AUR: the AUR package's pinned hash for the *source*
# tarball goes stale because Codeberg archives are not byte-stable).
# To bump: read the new script.js, then update both values below.

KROHNKITE_VERSION=0.9.9.2
KROHNKITE_SHA256=42f7f66531d366c74b5fc860381da3517ccb4cdccd1f80c122fcab6e9a8fcf7e
KROHNKITE_URL="https://codeberg.org/anametologin/Krohnkite/releases/download/${KROHNKITE_VERSION}/krohnkite.kwinscript"

krohnkite_installed() {
    [ -d /usr/share/kwin/scripts/krohnkite ] || [ -d "$DATA/kwin/scripts/krohnkite" ]
}

install_krohnkite() {
    local tmp
    tmp="$(mktemp -d)"
    curl -fsSL -o "$tmp/krohnkite.kwinscript" "$KROHNKITE_URL" || { rm -rf "$tmp"; die "could not download $KROHNKITE_URL"; }
    if ! echo "$KROHNKITE_SHA256  $tmp/krohnkite.kwinscript" | sha256sum -c --quiet -; then
        rm -rf "$tmp"
        die "krohnkite ${KROHNKITE_VERSION}: checksum mismatch, refusing to install"
    fi
    kpackagetool6 --type KWin/Script --install "$tmp/krohnkite.kwinscript" >/dev/null
    rm -rf "$tmp"
    log "krohnkite ${KROHNKITE_VERSION} installed (checksum verified)"
}

krohnkite_cfg() { kw --file kwinrc --group Script-krohnkite --key "$1" "$2"; }

configure_krohnkite() {
    local layout

    # Layout cycle (0 disables a layout): binary tree is the dwindle equivalent
    krohnkite_cfg binaryTreeLayoutOrder 1
    krohnkite_cfg monocleLayoutOrder 2
    krohnkite_cfg floatingLayoutOrder 3
    krohnkite_cfg spiralLayoutOrder 4
    for layout in tile threeColumn quarter stacked columns spread stair cascade; do
        krohnkite_cfg "${layout}LayoutOrder" 0
    done

    # Hyprland: gaps_out = 20, gaps_in = 5 (per side, so 10 between windows)
    for layout in Left Right Top Bottom; do krohnkite_cfg "screenGap$layout" 20; done
    krohnkite_cfg screenGapBetween 10

    # Utilities that float centered in Hyprland (window rules float-utilities / float-pip).
    # Matching is by window class (exact) and by title (substring).
    krohnkite_cfg floatUtility true
    krohnkite_cfg floatingClass "Bitwarden,bitwarden,org.pulseaudio.pavucontrol,pavucontrol,blueman-manager,nm-connection-editor,xdg-desktop-portal-gtk,xdg-desktop-portal-kde,org.kde.kcalc"
    krohnkite_cfg floatingTitle "Picture-in-Picture,Picture in picture,Open File,Save File,Save As"

    # Tiling-WM look, like Hyprland: no titlebars, focus follows mouse, Meta+drag
    # moves/resizes. (`setup.sh kwin` removes all of this again.)
    kw --file kwinrc --group org.kde.kdecoration2 --key NoPlugin true
    kw --file kwinrc --group Windows --key FocusPolicy FocusFollowsMouse
    kw --file kwinrc --group Windows --key NextFocusPrefersMouse true
    kw --file kwinrc --group MouseBindings --key CommandAllKey Meta
    kw --file kwinrc --group MouseBindings --key CommandAll1 Move
    kw --file kwinrc --group MouseBindings --key CommandAll3 Resize

    kw --file kwinrc --group Plugins --key krohnkiteEnabled true
    kwin_reconfigure
    apply_shortcuts_file "$HERE/shortcuts-tiling.tsv"
}

krohnkite_installed || install_krohnkite
configure_krohnkite
