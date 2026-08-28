# ssh-agent.fish — point every shell at the persistent, systemd socket-activated
# ssh-agent instead of a per-session one.
#
# Requires `systemctl --user enable --now ssh-agent.socket` (done once by
# install.sh). The socket path is stable across reboots and shells, so tools
# spawned outside an interactive shell (sandboxed subprocesses, cron, etc.)
# can reuse it too by exporting the same path explicitly. Load keys into it
# with `ssh-unlock` (shell/functions/ssh-unlock.fish).
set -gx SSH_AUTH_SOCK "$XDG_RUNTIME_DIR/ssh-agent.socket"
