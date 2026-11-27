---
name: secret
description: Environment variables, API keys, tokens, and credentials for every project. No project keeps a .env file, because values live in 1Password and reach programs through mise, so a missing .env is expected. Use whenever a task runs a dev server or tests, touches code that reads process.env or os.environ, mentions .env or a secret, fixes a missing-variable error, adds or changes a value, signs in through a browser, or saves or restores SSH, kube, or npm credentials.
---

# Secrets

Each project environment's secrets are one item in the 1Password vault `Dev`, named `<org>.<project>.<env>`, such as `zanroo.social-intelligence-api.dev`. The `secret` command stores them and mise runs programs with them. Work with names and paths, never values.

## Run a command

Run from the app folder. A monorepo root gets no secrets.

- `mise run pnpm <script>` runs with dev secrets, and `MISE_ENV=pre mise run pnpm <script>` with pre.
- `env PORT=3001 mise run pnpm dev` overrides a setting that is not secret.
- Plain `pnpm <script>` has no secrets. Use it for lint, typecheck, and unit tests.

mise prints a secret as `[redacted]` only when the whole value is on one line. Never print a value that contains a secret, such as a connection URL.

## Find what exists

- `mise.local.toml` has plain settings under `[env]` and secret names under `[tasks.pnpm].secrets`.
- `fnox.local.toml` maps each secret to its 1Password item.
- `secret list` lists every item.

`secret init` and `secret add` generate both files. Never edit or commit them.

## Missing variables

- If a variable is in the item but not in `mise.local.toml`, run `secret init` in the app folder.
- If the folder has no `fnox.local.toml`, as in a new clone or worktree, run `secret init` with one item per environment, such as `secret init zanroo.social-intelligence-web.dev zanroo.social-intelligence-web.pre`.
- If `secret list` and the project's docs don't settle which item to use, ask the user.

## Add or change a value

1. Tell the user the variable name, the item, and why the task needs it.
2. Call `request_secret` with `delivery: "file"`, then run `secret add <item> <NAME> <file>`. Add `--plain` for a value that is not secret, such as a port or a public URL. Without `request_secret`, ask the user to run `secret add <item> <NAME> -` in their own terminal, and wait until they confirm.
3. Run the command that needed the value.

## Browser sign-in

Use a signed-in browser profile if one exists. If sign-in needs a secret and the browser tool accepts a `secretRef`, call `request_secret` with `delivery: "secretRef"` and pass the reference to the tool. Otherwise ask the user to sign in in the shared browser, and wait until they confirm. Never put a credential, a test account's included, in a tool argument, script, note, screenshot, or recording. Store a reusable one with `secret add`.

## Machine files

SSH keys, `~/.kube/config`, and `~/.npmrc` are 1Password documents tagged `kind/file`. `secret save <item> <path>` stores one, and `secret restore <item> <path>` writes it back when the path is missing.

## When something blocks you

A guard blocks commands that expose values, such as `op`, `printenv`, `mise env`, and reading `.env` files. It can't catch everything, so never print, log, encode, or copy a value yourself, and never add code that prints `process.env` or `os.environ`.

- If the guard blocks a command, report the command and its reason, and stop that operation. Never work around the guard.
- If `mise run` fails with a 1Password, fnox, or auth error, stop and tell the user.
- If a value appears by accident, tell the user where it appeared without repeating it.
