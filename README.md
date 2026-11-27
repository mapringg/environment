# environment

1. `gh repo clone mapringg/environment ~/code/mapringg/environment && bash ~/code/mapringg/environment/install.sh`
2. `secret setup` with 1Password item `1Password Service Account (Dev)`, then rerun `install.sh`.
3. `cliproxy-login claude|codex` for each account.
4. T3 → Settings → Providers → Usage providers → Add hub: `http://127.0.0.1:8317`, key in
   `~/.config/cliproxy/management-key`.
5. Executor: connect OAuth for `paper`, `jam`, and `mobbin` at `https://<tailscale-dns>:4789` (token in `~/.executor/server-control/auth.json`), and for `tldraw` at `http://127.0.0.1:4789` on the Executor host.
6. Codex: `/hooks` once.

Update `vendor/tstack` with `bin/vendor-refresh`.
