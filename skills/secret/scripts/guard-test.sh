#!/usr/bin/env bash
set -uo pipefail
G="$(dirname "$0")/guard.py"
D=$(mktemp -d)
trap 'rm -rf "$D"' EXIT
echo 'FAKE=1' >"$D/.env"
echo 'FAKE=1' >"$D/.env.example"
mkdir -p "$D/clean/src" "$D/nested/app"
echo 'FAKE=1' >"$D/nested/app/.env"
fail=0

check() {
  local want=$1 tool=$2 input=$3 got
  printf '%s' "$(jq -nc --arg t "$tool" --argjson i "$input" --arg c "$D" '{tool_name:$t,tool_input:$i,cwd:$c}')" |
    python3 -I "$G" 2>/dev/null
  got=$([ $? = 2 ] && echo block || echo allow)
  [ "$got" = "$want" ] || { echo "FAIL want=$want got=$got $tool $input"; fail=1; }
}
bash_is() { check "$1" Bash "$(jq -nc --arg c "$2" '{command:$c}')"; }

for c in 'cat .env' 'less ./.env' 'head -1 .env' 'cp .env.example .env' 'echo X=1 >> .env' 'tee -a .env.local' \
  'op read op://Dev/x/y' 'op --vault Dev item get app.dev --format json' '~/.local/bin/op item get x' \
  'echo hi; op signin' 'op inject -i t' 'fnox -c fnox.local.toml -P dev get X' 'fnox export' 'mise x -- fnox exec -- sh' \
  'printenv' 'printenv HOME' 'env' 'env | grep X' 'FOO=1 env' 'node -e 1 && env' 'env -0' 'export -p' 'declare -px' \
  'mise env' 'mise --cd apps/web env' 'mise --cd apps/web x --secrets API_TOKEN -- node -p 1' \
  'mise set X=1' 'cat /proc/123/environ' 'cat ~/.config/fnox/config.toml' 'ls ~/.config/op' 'cat ~/.config/fnox/age.txt' \
  $'fnox \\\n  get OP_SERVICE_ACCOUNT_TOKEN' 'grep -r KEY ~/.config' 'grep -rn KEY ~' 'cd ~/.config && cat fnox/config.toml' \
  'cd ~/.config/fnox; ls' 'rg --hidden KEY ~' 'rg KEY ~/.config' 'tar czf /tmp/x.tgz ~/.config' \
  'mise run -r pnpm dev' 'mise --raw run pnpm dev' 'mise run --raw pnpm dev' 'MISE_RAW=1 mise run pnpm dev' 'mise run pnpm exec printenv' 'env FOO=1 printenv' 'env printenv' 'env fnox export' \
  'timeout 5 printenv' 'timeout 10 fnox export' 'cat <.env' 'while read l; do :; done < .env' 'node --env-file=.env x.js' \
  'npx printenv' 'git add .env' 'cat app/.env' 'ps auxe' 'ps e' 'grep -R TOKEN .' 'grep -rn KEY nested' 'rg --hidden --no-ignore KEY .' \
  "docker inspect -f '{{.Config}}' app" "docker inspect --format '{{json .}}' app" 'docker compose -f compose.yml config' 'docker compose config --format json' \
  "rg --hidden --glob='!node_modules/**' TOKEN nested" 'docker exec app env' 'docker compose exec api printenv' 'docker inspect app' 'fnox x -- sh' 'fnox ex -- sh' 'cat $XDG_CONFIG_HOME/fnox/config.toml' \
  'cat ~/.ssh/zanroo' 'cp ~/.ssh/id_ed25519 /tmp/k' 'cat ~/.kube/config' 'cat ~/.npmrc' 'base64 $HOME/.npmrc' 'sudo cat /etc/wireguard/wg0.conf' \
  'secret save a ~/.ssh/k; cat ~/.ssh/k' 'cmp ~/.ssh/zanroo /tmp/k' 'cmp -l ~/.ssh/zanroo /tmp/k' 'cmp -s -b .env app/.env' \
  'cmp -s ~/.ssh/zanroo /tmp/k && cat ~/.ssh/zanroo' 'cmp -s ~/.ssh/zanroo $(cat ~/.ssh/zanroo)' 'cmp -s ~/.config/fnox/age.txt /tmp/a' \
  'cat ~/.executor/data.db' 'cat ~/.executor/server-control/auth.json' 'secret export mapringg.thiwaclinic-api.dev' 'secret export'; do
  bash_is block "$c"
done
for c in 'cat .env.example' 'git status' 'pnpm exec vitest run' 'mise run pnpm dev' 'mise run pnpm exec vitest run x' \
  'git ls-files | rg ".env"' 'rg -n "\.env" src' 'grep -r dotenv src'  'docker compose up -d' \
  'docker inspect --format "{{.State.Status}}" app' 'docker compose config --services' 'cat .env.sample' \
  "rg --hidden --glob='!.env*' TOKEN nested" 'mise run pnpm -r build' 'mise run pnpm dev --raw' 'mise r pnpm --raw dev' 'grep -rn KEY clean' "grep -rn KEY --exclude='.env*' ." 'rg KEY .' 'cat .env.template' \
  'git commit -m "Copy fnox and mise env files on worktree setup"' 'env FOO=1 node x.js' \
  'pnpm env use 22' 'ls --env' 'environment=1 node x' 'secret add a B /tmp/f' 'secret list' 'mise trust -q x' \
  'export FOO=1' 'git log -p --oneline' "rg --files -g '!.env*'" 'rg KEY ~' 'grep -rn KEY src' 'ls ~/.config' \
  'find . -name "*.ts"' 'rm .env' 'rm -f .env' 'git rm --cached .env' 'git status .env' 'find ~ -maxdepth 1' \
  'du -sh ~' 'ls -la ~/.config' 'mise run pnpm env use 22' 'timeout 60 pnpm test' 'env -u FOO node x.js' 'cd ~/code && git status' 'ls -la ~' \
  'cat ~/.ssh/config' 'cat ~/.ssh/id_ed25519.pub' 'ssh-keygen -lf ~/.ssh/id_ed25519.pub' 'cat ~/.ssh/known_hosts' 'cat apps/web/.npmrc' \
  'kubectl get ns' 'secret save zanroo.kube ~/.kube/config' 'secret restore zanroo.ssh-inf ~/.ssh/zanroo' \
  'cmp -s ~/.ssh/zanroo /tmp/k' 'cmp --silent "$HOME/.npmrc" ~/.npmrc.bak && echo same' 'cmp -s .env app/.env || echo differ' \
  'cmp -s ~/.kube/config /tmp/kube; echo $?'; do
  bash_is allow "$c"
done
check block Read '{"file_path":"/x/.env"}'
check block Read '{"file_path":"/x/.env.local"}'
check allow Read '{"file_path":"/x/.env.example"}'
check block Read '{"file_path":"/home/u/.config/fnox/config.toml"}'
check allow Edit '{"file_path":"/x/a.mjs","new_string":"apps/api/.env"}'
check block Write '{"file_path":"/x/.env","content":"A=1"}'
check block Grep '{"pattern":"KEY","glob":"**/.env*"}'
check allow Grep '{"pattern":"\\.env","path":"src"}'
check block Grep '{"pattern":"KEY","path":"/home/mapring/.config"}'
check block Grep '{"pattern":"KEY","path":"/home/mapring"}'
check block Grep '{"pattern":"KEY","output_mode":"content"}'
check allow Grep '{"pattern":"KEY"}'
check allow Grep '{"pattern":"KEY","output_mode":"content","glob":"*.ts"}'
check block Grep '{"pattern":"KEY","output_mode":"content","glob":".env*"}'
check allow Grep '{"pattern":"KEY","path":"clean"}'
check allow Glob '{"pattern":"*.md","path":"/home/mapring"}'
check allow Grep '{"pattern":"KEY","path":"/home/mapring/code"}'
check block Read '{"file_path":"/home/mapring/.config/op/config"}'
check block Read '{"file_path":"/home/mapring/.executor/data.db"}'
check block Read '{"file_path":"/home/mapring/.executor/server-control/auth.json"}'
check block Read '{"file_path":"/home/mapring/.ssh/zanroo"}'
check block Read '{"file_path":"/home/mapring/.kube/config"}'
check block Read '{"file_path":"/home/mapring/.npmrc"}'
check allow Read '{"file_path":"/home/mapring/.ssh/config"}'
check allow Read '{"file_path":"/x/apps/web/.npmrc"}'
check block apply_patch '{"command":"*** Begin Patch\n*** Add File: apps/api/.env\n+X=1\n*** End Patch"}'
[ $fail = 0 ] && echo "secrets-guard: all cases pass"
exit $fail
