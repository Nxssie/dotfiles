# ssh-unlock — load key(s) into the persistent ssh-agent (see conf.d/ssh-agent.fish)
# with a TTL, so a single unlock covers a whole workday instead of prompting
# per shell/tool. With no key arguments it globs every id_* private key under
# ~/.ssh — but since that glob would silently trust any file dropped into
# ~/.ssh by someone else with write access to the account, it always lists
# what it found and requires an explicit y/N before calling ssh-add (explicit
# key arguments skip the prompt — you already named exactly what to load).
# Note: OpenSSH still prompts once per key file even when they share a
# passphrase (no dedup across files), but typing the same passphrase N times
# beats N separate ssh-unlock invocations. The agent auto-drops everything
# together when the shared TTL expires.
function ssh-unlock --description 'Load SSH key(s) into the agent with a TTL (default 8h)'
    set -l ttl 28800
    set -l keys $argv
    set -l discovered 0

    if test (count $argv) -ge 1; and string match -qr '^[0-9]+$' -- $argv[1]
        set ttl $argv[1]
        set keys $argv[2..-1]
    end

    if test (count $keys) -eq 0
        set discovered 1
        for f in $HOME/.ssh/id_*
            if test -f $f; and not string match -q '*.pub' -- $f
                set -a keys $f
            end
        end
    end

    if test (count $keys) -eq 0
        echo "ssh-unlock: no private keys found in ~/.ssh/id_*" >&2
        return 1
    end

    if test $discovered -eq 1
        echo "ssh-unlock: found "(count $keys)" key(s) in ~/.ssh:"
        for k in $keys
            echo "  $k"
        end
        read -l -P 'Load all of these into the agent? [y/N] ' confirm
        if not string match -qr '^[Yy]' -- $confirm
            echo "ssh-unlock: aborted" >&2
            return 1
        end
    end

    ssh-add -t $ttl $keys
end
