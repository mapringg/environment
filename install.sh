#!/usr/bin/env bash
set -euo pipefail

E=$(cd "$(dirname "$0")" && pwd)
OS=$(uname -s)
HOST=$(hostname -s)
IS_HUB=false
[ "$HOST" = ubuntu ] && IS_HUB=true
PATH=~/.local/bin:/opt/homebrew/bin:/usr/local/bin:$PATH

HUB_DNS=""
if [ "$IS_HUB" = false ]; then
  HUB_DNS=$(tailscale status --json 2>/dev/null | python3 -c '
import json, sys
d = json.load(sys.stdin)
for p in (d.get("Peer") or {}).values():
    if (p.get("HostName") or "").lower() == "ubuntu":
        print((p.get("DNSName") or "").rstrip("."))
        break
' 2>/dev/null || true)
fi
if [ "$IS_HUB" = true ] || [ -z "$HUB_DNS" ]; then
  CLIPROXY_URL="http://127.0.0.1:8317"
  EXECUTOR_URL=""
else
  CLIPROXY_URL="https://${HUB_DNS}:8317"
  EXECUTOR_URL="https://${HUB_DNS}:4789"
fi

MISE=$(command -v mise || true)
if [ -z "$MISE" ]; then
  curl -fsSL https://mise.run/bash | sh
  MISE=~/.local/bin/mise
fi
"$MISE" use -g node
"$MISE" use -g claude codex op 'fnox[workflow=release.yml]' age ripgrep github:router-for-me/CLIProxyAPI npm:executor@1.6.11

link_skills() {
  local dst=$1 s
  mkdir -p "$dst"
  for s in $S; do
    ln -sfn "$s" "$dst/$(basename "$s")"
  done
  for s in "$dst"/*; do
    if [ -L "$s" ] && [ ! -e "$s" ]; then
      rm -f "$s"
    fi
  done
}

mkdir -p ~/.claude/skills ~/.codex/skills ~/.local/bin ~/.config/git
S=$(dirname "$E"/skills/*/SKILL.md "$E"/vendor/tstack/skills/*/SKILL.md)
link_skills ~/.claude/skills
link_skills ~/.codex/skills
python3 - "$E/claude/settings.json" "$CLIPROXY_URL" <<'PY'
import json, os, sys
src = json.load(open(sys.argv[1]))
src.setdefault("env", {})["ANTHROPIC_BASE_URL"] = sys.argv[2]
p = os.path.expanduser("~/.claude/settings.json")
if os.path.islink(p):
    os.unlink(p)
with open(p, "w") as f:
    json.dump(src, f, indent=2)
    f.write("\n")
PY
ln -sf "$E/AGENTS.md" ~/.claude/CLAUDE.md
ln -sf "$E/AGENTS.md" ~/.codex/AGENTS.md
rm -rf ~/.codex/skill-sources/pstack ~/.claude/rules ~/.claude/agents ~/.local/bin/commit-guard
for agy_cfg in ~/.t3/userdata/providers/antigravity/*/config; do
  [ -d "$agy_cfg" ] || continue
  mkdir -p "$agy_cfg/plugins/environment/rules"
  link_skills "$agy_cfg/skills"
  printf '{\n  "name": "environment"\n}\n' > "$agy_cfg/plugins/environment/plugin.json"
  ln -sf "$E/AGENTS.md" "$agy_cfg/plugins/environment/rules/AGENTS.md"
done
python3 - "$E/t3/settings.json" <<'PY'
import json, os, sys
src = json.load(open(sys.argv[1]))
p = os.path.expanduser("~/.t3/userdata/settings.json")
os.makedirs(os.path.dirname(p), mode=0o700, exist_ok=True)
d = json.load(open(p)) if os.path.exists(p) else {}
def merge(dst, patch):
    for k, v in patch.items():
        if isinstance(v, dict) and isinstance(dst.get(k), dict):
            merge(dst[k], v)
        else:
            dst[k] = v
merge(d, src)
with open(p, "w") as f:
    json.dump(d, f, indent=2)
    f.write("\n")
PY
ln -sf "$E/skills/secret/scripts/secret" ~/.local/bin/secret
ln -sf "$E/bin/cliproxy-login" ~/.local/bin/
[ -f ~/.codex/config.toml ] || cp "$E/codex/config.toml" ~/.codex/config.toml
python3 - "$CLIPROXY_URL" <<'PY'
import os, re, sys
p = os.path.expanduser("~/.codex/config.toml")
text = open(p).read()
text = re.sub(r'^base_url = ".*"$', f'base_url = "{sys.argv[1]}/v1"', text, flags=re.M)
open(p, "w").write(text)
PY
PATH=~/.local/bin:/opt/homebrew/bin:/usr/local/bin:$PATH

mkdir -p ~/.ssh/config.d && chmod 700 ~/.ssh ~/.ssh/config.d
ln -sf "$E/ssh/config" ~/.ssh/config
if [ -f ~/.config/fnox/config.toml ]; then
  secret restore mapringg.ssh-github ~/.ssh/id_ed25519
  secret restore mapringg.ssh-hosts ~/.ssh/config.d/hosts
  secret restore zanroo.ssh-inf ~/.ssh/zanroo
  secret restore codecipher.ssh ~/.ssh/codecipher
  secret restore zanroo.kube ~/.kube/config
  secret restore zanroo.npmrc ~/.npmrc
  secret restore mapringg.cliproxy-key ~/.config/cliproxy/key
  if [ "$IS_HUB" = true ]; then
    secret restore mapringg.cliproxy-config ~/.config/cliproxy/config.yaml
    secret restore mapringg.cliproxy-management-key ~/.config/cliproxy/management-key
  else
    secret restore mapringg.executor-auth ~/.executor/ubuntu-auth.json
  fi
  if [ "$OS" = Linux ]; then
    if sudo -v 2>/dev/null && ! sudo test -e /etc/wireguard/wg0.conf; then
      W=$(mktemp -d)
      secret restore zanroo.wireguard "$W/wg0.conf"
      sudo install -D -m 600 -o root -g root "$W/wg0.conf" /etc/wireguard/wg0.conf
      rm -rf "$W"
    fi
    sudo -n true 2>/dev/null && sudo systemctl enable -q wg-quick@wg0
  fi
fi

if [ "$OS" = Linux ]; then
  if [ -f ~/.config/cliproxy/key ]; then
    (umask 077 && printf 'CLIPROXY_API_KEY=%s\n' "$(cat ~/.config/cliproxy/key)" > ~/.config/cliproxy/codex.env)
    mkdir -p ~/.config/systemd/user/t3code.service.d
    cat > ~/.config/systemd/user/t3code.service.d/cliproxy.conf <<EOF
[Service]
EnvironmentFile=$HOME/.config/cliproxy/codex.env
EOF
    systemctl --user daemon-reload
  fi
  grep -q 'CLIPROXY_API_KEY' ~/.profile || cat >> ~/.profile <<'PROFILE'
[ -f ~/.config/cliproxy/key ] && export CLIPROXY_API_KEY="$(cat ~/.config/cliproxy/key)"
PROFILE
fi

if [ "$IS_HUB" = true ] && [ "$OS" = Linux ]; then
  mkdir -p ~/.config/systemd/user
  cat > ~/.config/systemd/user/cliproxyapi.service <<'EOF'
[Unit]
Description=CLIProxyAPI for Claude Code and Codex
After=network-online.target
Wants=network-online.target

[Service]
WorkingDirectory=%h/.config/cliproxy
ExecStart=%h/.local/bin/mise x -- cli-proxy-api -config %h/.config/cliproxy/config.yaml
Restart=always
RestartSec=10

[Install]
WantedBy=default.target
EOF
  systemctl --user daemon-reload
  [ -f ~/.config/cliproxy/config.yaml ] && systemctl --user enable -q --now cliproxyapi

  tailscale serve status --json 2>/dev/null | grep -q '127.0.0.1:8317' || tailscale serve --bg --https=8317 http://127.0.0.1:8317 >/dev/null

  "$MISE" x -- executor service status >/dev/null 2>&1 || "$MISE" x -- executor install
  TS_DNS=$(tailscale status --json 2>/dev/null | python3 -c 'import json,sys; print(json.load(sys.stdin).get("Self",{}).get("DNSName","").rstrip("."))' 2>/dev/null || true)
  if [ -n "$TS_DNS" ]; then
    mkdir -p ~/.config/systemd/user/sh.executor.daemon.service.d
    cat > ~/.config/systemd/user/sh.executor.daemon.service.d/tailscale.conf <<EOF
[Service]
Environment=EXECUTOR_WEB_BASE_URL=https://${TS_DNS}:4789
EOF
    systemctl --user daemon-reload
    systemctl --user restart sh.executor.daemon.service
    for _ in $(seq 1 20); do "$MISE" x -- executor tools integrations >/dev/null 2>&1 && break; sleep 0.25; done
    tailscale serve status --json 2>/dev/null | grep -q '127.0.0.1:4789' || tailscale serve --bg --https=4789 http://127.0.0.1:4789 >/dev/null
  fi
elif [ -n "$EXECUTOR_URL" ]; then
  "$MISE" x -- executor server add ubuntu "$EXECUTOR_URL" --default --header-env Authorization=EXECUTOR_AUTH_HEADER >/dev/null
fi
python3 "$E/bin/sync-mcp"

for p in fnox.local.toml 'fnox.*.local.toml' mise.local.toml 'mise.*.local.toml'; do
  grep -qxF "$p" ~/.config/git/ignore 2>/dev/null || echo "$p" >> ~/.config/git/ignore
done
mkdir -p ~/.config/environment.d
cat > ~/.config/environment.d/telemetry.conf <<'EOF'
DO_NOT_TRACK=1
NEXT_TELEMETRY_DISABLED=1
TURBO_TELEMETRY_DISABLED=1
TURBO_NO_UPDATE_NOTIFIER=1
ASTRO_TELEMETRY_DISABLED=1
EXPO_NO_TELEMETRY=1
EOF
if [ "$OS" = Darwin ]; then
  touch ~/.zshrc
  grep -q 'HOME/.local/bin' ~/.zshrc || echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc
  grep -q 'CLIPROXY_API_KEY' ~/.zshrc || echo '[ -f ~/.config/cliproxy/key ] && export CLIPROXY_API_KEY="$(cat ~/.config/cliproxy/key)"' >> ~/.zshrc
  grep -q 'environment.d/telemetry.conf' ~/.zshrc || cat >> ~/.zshrc <<'ZSH'
set -a; . ~/.config/environment.d/telemetry.conf; set +a
ZSH
else
  grep -q 'environment.d/telemetry.conf' ~/.bashrc || cat >> ~/.bashrc <<'BASH'
set -a; . ~/.config/environment.d/telemetry.conf; set +a
BASH
fi

# Ubuntu blocks unprivileged user namespaces, so the Chrome builds that verify skills pin under
# ~/.cache/verification lose their sandbox and agents fall back to --no-sandbox. This profile, like
# the one `t3 browser setup` writes, gives those binaries their sandbox back.
if [ -d /sys/kernel/security/apparmor ] && sudo -v 2>/dev/null && ! sudo test -e /etc/apparmor.d/verification-chrome; then
  sudo tee /etc/apparmor.d/verification-chrome >/dev/null <<'APPARMOR'
abi <abi/4.0>,
include <tunables/global>

profile verification-chrome /**/verification/**/{chrome-linux64/chrome,chrome-headless-shell-linux64/chrome-headless-shell} flags=(unconfined) {
  userns,

  include if exists <local/verification-chrome>
}
APPARMOR
  sudo apparmor_parser -r /etc/apparmor.d/verification-chrome
fi
