---
name: setup-environment
description: Install or refresh shared tooling, provider logins, and T3 integrations on a machine.
---

# Set up the environment

1. `gh repo clone mapringg/environment ~/code/mapringg/environment && bash ~/code/mapringg/environment/install.sh`
2. `secret setup` with 1Password item `1Password Service Account (Dev)`, then rerun `install.sh`.
3. `cliproxy-login claude|codex` for each account.
4. T3 → Settings → Providers → Usage providers → Add hub: `http://127.0.0.1:8317`, key in
   `~/.config/cliproxy/management-key`.
5. Executor: connect OAuth for `paper`, `jam`, and `mobbin` at `https://<tailscale-dns>:4789` (token in `~/.executor/server-control/auth.json`), and for `tldraw` at `http://127.0.0.1:4789` on the Executor host.
6. Codex: `/hooks` once.

Update `vendor/tstack` with `bin/vendor-refresh`.

## Desktop power

Use these requests in T3 chat.

| Request                  | What to do                                                                  |
| ------------------------ | --------------------------------------------------------------------------- |
| `desktop wake`           | Send Wake-on-LAN from Ubuntu. Wait until the desktop T3 environment answers. |
| `desktop suspend`        | Check for active work, suspend Ubuntu, then confirm the desktop goes offline. |
| `desktop reboot-windows` | Wake if needed, check for active work, then run the Windows reboot helper.    |

### Wake

Run `bin/wake-desktop` on the Ubuntu hub with the stored `DESKTOP_MAC` on standard input.
From Apple, connect to Tailscale and run this with your signed-in 1Password CLI.

```sh
op read 'op://Dev/mapringg.machines.ops/DESKTOP_MAC' |
  ssh ubuntu '~/code/mapringg/environment/bin/wake-desktop'
```

The helper reads the Ethernet MAC from standard input. Use the stored field without showing it in chat.
Wait for the desktop T3 environment to become reachable before delegating there.
Wake-on-LAN needs Ethernet and standby power. A full shutdown wakes only if the firmware supports it.

### Suspend

Before suspending, check for active work on the desktop. Use a terminal so sudo can prompt if needed.

```sh
ssh -t desktop 'sudo systemctl suspend'
```

### Reboot into Windows

Run the existing `reboot-windows` Bash function on desktop Ubuntu after checking for active work.

```sh
ssh -t desktop 'bash -ic reboot-windows'
```

The helper selects Windows for the next boot. Check the `windows` Tailscale device after reboot.
