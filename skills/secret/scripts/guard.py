#!/usr/bin/env python3
import fnmatch
import json
import os
import re
import shlex
import sys

ENV_NAME = re.compile(r"^\.env(?:\.(?!(?:example|sample|template)$)[\w.-]+)?$")
ENV_IN_TEXT = r"(?<![\w.-])\.env(?:\.(?!(?:example|sample|template)\b)[\w.-]+)?"
SECRET_PATH = re.compile(ENV_IN_TEXT + r"(?![\w.-])|\.config/(?:fnox|op)\b|\.executor\b|\bage\.txt\b|/proc/[^\s]*/environ")
ALWAYS_SECRET = re.compile(r"\.config/(?:fnox|op)\b|\.executor\b|\bage\.txt\b|\bfnox/config\.toml\b|/proc/[^\s'\"]*/environ|\bMISE_RAW=")
FILES = re.compile(
    r"\.ssh/(?!(?:config|known_hosts|authorized_keys)(?![\w.-]))[\w-]+(?![\w.-])|\.kube/config\b"
    r"|(?:^|[\s'\"=])(?:~|\$HOME|\$\{HOME\}|/home/[\w-]+)/\.npmrc\b|/etc/wireguard\b"
)
SECRET_CLI = re.compile(r"(?:^|[;&|\s])secret\s+(?:save|restore)\s+\S+\s+\S+")
ARG = r"""(?:'[^']*'|"(?:[^"`$]|\$(?!\())*"|[^\s;&|()<>`'"]+)"""
QUIET_CMP = re.compile(r"(?:^|(?<=[;&|(\s]))cmp\s+(?:(?:-s|--quiet|--silent)\s+)+" + ARG + r"\s+" + ARG + r"(?=\s*(?:$|[;&|)\n]))")
WRITE_ENV = re.compile(
    r"(?:>>?|\btee\s+(?:-a\s+)?)\s*['\"]?[^\s'\"]*" + ENV_IN_TEXT + r"['\"]?(?:\s|$)"
    r"|\b(?:cp|mv|ln)\b[^;&|\n]*\s['\"]?[^\s'\"]*" + ENV_IN_TEXT + r"['\"]?\s*(?:$|[;&|\n])"
)
READ_ENV = re.compile(r"<\s*['\"]?[^\s'\"<]*" + ENV_IN_TEXT + r"['\"]?(?:\s|$)")
SPLIT = re.compile(r"\|\||&&|[;|&\n()`]|\$\(")
OP_BLOCKED = {"read", "inject", "run", "signin", "service-account", "environment"}
OP_BLOCKED_PAIRS = {("item", "get"), ("document", "get")}
FNOX_BLOCKED = {"get", "export", "exec", "ex", "x", "env", "edit", "mcp", "tui"}
SECRET_BLOCKED = {"export"}
SEARCHERS = {"grep", "egrep", "fgrep", "rg", "ag", "ack"}
HOME = os.path.expanduser("~")
PROTECTED = [os.path.realpath(os.path.join(HOME, d)) for d in (".config/fnox", ".config/op", ".executor")]
WALKERS = {"grep", "egrep", "fgrep", "tar", "zip", "rsync"}
HIDDEN_WALKERS = {"rg", "ag"}
MISE_SUBS = {"env", "set", "x", "exec", "r", "run", "w", "watch", "t", "task", "tasks"}
WRAPPERS = {"sudo", "command", "exec", "nohup", "time", "setsid", "npx", "bunx"}
RUNNERS = {"pnpm", "npm", "yarn", "bun"}
REMOVERS = {"rm", "unlink"}
GIT_SAFE = {"rm", "status", "clean", "check-ignore", "ls-files", "restore"}

REASON = (
    "Blocked by the secrets guard: this operation may expose secret values. "
    "Read the `secret` skill (skills/secret/SKILL.md in the environment repository) "
    "for running programs, inspecting variable names, and adding values. "
    "Report this blocked operation and its reason."
)


def words(segment):
    try:
        return shlex.split(segment)
    except ValueError:
        return segment.split()


def existing_env_file(token, cwd):
    name = os.path.basename(token.rstrip("/"))
    if not ENV_NAME.match(name):
        return False
    if os.path.isfile(os.path.join(cwd, os.path.expanduser(token))):
        return True
    return not os.path.isabs(os.path.expanduser(token)) and env_file_below(cwd, named=name)


def real(token, cwd):
    return os.path.realpath(os.path.join(cwd, os.path.expanduser(token)))


def inside(path):
    return any(path == d or path.startswith(d + "/") for d in PROTECTED)


def above(path):
    return any(d.startswith(path.rstrip("/") + "/") for d in PROTECTED)


SKIP_DIRS = {".git", "node_modules", ".next", "dist", "build", ".turbo", ".cache"}


def env_file_below(root, limit=3000, named=None):
    if not os.path.isdir(root):
        return False
    seen = 0
    for path, dirs, files in os.walk(root):
        dirs[:] = [d for d in dirs if d not in SKIP_DIRS]
        if any(f == named if named else ENV_NAME.match(f) for f in files):
            return True
        seen += 1
        if seen > limit:
            return False
    return False


def reads_env_tree(exe, args, roots, cwd):
    recursive = exe in {"grep", "egrep", "fgrep"} and any(re.match(r"^-[a-zA-Z]*[rR]|^--recursive|^--dereference-recursive", a) for a in args)
    recursive = recursive or (exe in HIDDEN_WALKERS and any(a in {"--hidden", "-u", "-uu", "-uuu", "--no-ignore"} for a in args))
    excluded = any(re.search(r"(?:exclude|^!|--glob=!|^-g!).*\.env", a) for a in args)
    return recursive and not excluded and any(env_file_below(r) for r in roots or [cwd])


def walks_protected(exe, args, roots, cwd):
    recursive = exe in WALKERS and (exe != "grep" or any(re.match(r"^-[a-zA-Z]*[rR]|^--recursive|^--dereference-recursive", a) for a in args))
    recursive = recursive or (exe in {"cp", "ls", "chmod"} and any(re.match(r"^-[a-zA-Z]*[rR]", a) for a in args))
    if exe in HIDDEN_WALKERS:
        hidden = any(a in {"--hidden", "-u", "-uu", "-uuu", "--no-ignore"} for a in args)
        return any(above(r) and (hidden or r.startswith(os.path.join(HOME, ".config"))) for r in roots or [cwd])
    return recursive and any(above(r) for r in roots or [cwd])


def strip_prefix(argv):
    while argv:
        head = os.path.basename(argv[0])
        if re.match(r"^[A-Za-z_]\w*=", argv[0]) or head in WRAPPERS:
            argv = argv[1:]
        elif head == "timeout":
            argv = argv[1:]
            while argv and (argv[0].startswith("-") or re.match(r"^\d", argv[0])):
                argv = argv[1:]
        elif head in RUNNERS and len(argv) > 1 and argv[1] in {"exec", "dlx", "x"}:
            argv = argv[2:]
        else:
            break
    return argv


def blocked_words(argv, cwd):
    argv = strip_prefix(argv)
    if not argv:
        return False
    exe, args = os.path.basename(argv[0]), argv[1:]
    if "--" in args and blocked_words(args[args.index("--") + 1 :], cwd):
        return True
    plain = [a for a in args if not a.startswith("-")]
    if exe == "op":
        return bool(OP_BLOCKED & set(plain)) or any(p in OP_BLOCKED_PAIRS for p in zip(plain, plain[1:]))
    if exe == "fnox":
        return bool(FNOX_BLOCKED & set(plain))
    if exe == "secret":
        return bool(SECRET_BLOCKED & set(plain))
    if exe == "mise":
        valued = {"-C", "--cd", "-E", "--env", "-P", "--profile", "-j", "--jobs"}
        first = next((a for i, a in enumerate(args) if not a.startswith("-") and (i == 0 or args[i - 1] not in valued)), None)
        if first in {"env", "set"}:
            return True
        sub = next((a for a in plain if a in MISE_SUBS - {"env", "set"}), None)
        own = args[: args.index(sub) + 1] if sub else args
        if sub in {"r", "run", "w", "watch", "t", "task", "tasks"}:
            rest = args[args.index(sub) + 1 :]
            own += rest[: next((i for i, a in enumerate(rest) if not a.startswith("-")), len(rest))]
        elif sub in {"x", "exec"}:
            rest = args[args.index(sub) + 1 :]
            own += rest[: rest.index("--")] if "--" in rest else rest
        raw = any(a in {"-r", "--raw"} or a.startswith(("--secrets", "--raw=")) for a in own)
        if sub is not None and raw:
            return True
        return sub is not None and blocked_words(args[args.index(sub) + 1 :], cwd)
    if exe == "ps" and any(re.match(r"^[a-zA-Z]*e[a-zA-Z]*$", a) and not a.startswith("-") for a in args[:2]):
        return True
    if exe == "printenv":
        return True
    if exe == "env":
        rest = args
        while rest and re.match(r"^(-0|--null|-i|--ignore-environment|-u|--unset=.*|[A-Za-z_]\w*=.*)$", rest[0]):
            rest = rest[2:] if rest[0] == "-u" else rest[1:]
        return not rest or blocked_words(rest, cwd)
    if exe in {"export", "declare", "typeset"}:
        return not plain and any(re.match(r"^-[a-zA-Z]*[px]", a) for a in args)
    if any(inside(real(a, cwd)) for a in plain):
        return True
    if exe == "cmp" and QUIET_CMP.fullmatch(shlex.join(argv)):
        return False
    if exe in REMOVERS or (exe == "git" and plain[:1] and plain[0] in GIT_SAFE):
        return False
    if any(existing_env_file(a.split("=", 1)[1], cwd) for a in args if a.startswith("-") and "=" in a):
        return True
    if exe in SEARCHERS and not {"-e", "--regexp", "-f", "--file"} & set(args):
        plain = plain[1:]
    roots = [real(a, cwd) for a in plain if not re.search(r"[*?!\[]", a)]
    if exe in WALKERS | HIDDEN_WALKERS | {"cp", "ls", "chmod"} and walks_protected(exe, args, roots, cwd):
        return True
    if reads_env_tree(exe, args, roots, cwd):
        return True
    if exe == "docker":
        if plain[:1] == ["exec"] or plain[:2] == ["compose", "exec"]:
            return any(os.path.basename(a) in {"env", "printenv"} for a in plain)
        if plain[:1] == ["compose"] and next((a for a in plain[1:] if a not in args or not re.match(r"^[\w./-]+\.ya?ml$", a)), None) == "config":
            return not {"--services", "--volumes", "--profiles", "--images", "-q", "--quiet"} & set(args)
        if plain[:1] == ["inspect"] or plain[:2] == ["container", "inspect"]:
            fmt = next((args[i + 1] for i, a in enumerate(args[:-1]) if a in {"-f", "--format"}), None)
            fmt = fmt or next((a.split("=", 1)[1] for a in args if a.startswith("--format=")), None)
            return fmt is None or bool(re.search(r"Env|Config|json\s+\.\s*}}", fmt, re.I))
    return any(existing_env_file(a, cwd) for a in plain)


def bash_blocked(command, cwd):
    command = command.replace("\\\n", " ")
    if ALWAYS_SECRET.search(command) or WRITE_ENV.search(command) or READ_ENV.search(command):
        return True
    if FILES.search(QUIET_CMP.sub(" ", SECRET_CLI.sub(" ", command))):
        return True
    for segment in SPLIT.split(command):
        argv = words(segment)
        if argv and argv[0] in {"cd", "pushd"}:
            cwd = real(argv[1] if len(argv) > 1 else "~", cwd)
            continue
        if blocked_words(argv, cwd):
            return True
    return False


def strings(value):
    if isinstance(value, str):
        yield value
    elif isinstance(value, dict):
        for v in value.values():
            yield from strings(v)
    elif isinstance(value, list):
        for v in value:
            yield from strings(v)


def main():
    try:
        event = json.load(sys.stdin)
    except ValueError:
        return
    tool = event.get("tool_name", "")
    data = event.get("tool_input") or {}
    cwd = event.get("cwd") or os.getcwd()
    if tool == "Bash":
        blocked = bash_blocked(data.get("command", ""), cwd)
    else:
        paths = [data.get(k, "") for k in ("file_path", "path", "glob", "notebook_path")]
        paths += re.findall(r"^\*\*\* (?:Add|Update|Delete|Move to:?) File: (.+)$", "\n".join(strings(data)), re.M)
        paths = [x for x in paths if isinstance(x, str) and x]
        blocked = any(SECRET_PATH.search(x) or FILES.search(x) or inside(real(x, cwd)) for x in paths)
        root = real(data.get("path") or cwd, cwd)
        blocked = blocked or (tool == "Grep" and above(root))
        glob = data.get("glob", "") or ""
        hidden = ".env" if glob and not fnmatch.fnmatch(".env", glob.rsplit("/", 1)[-1]) else glob
        content = data.get("output_mode") == "content"
        blocked = blocked or (
            tool == "Grep" and content and ".env" not in hidden and env_file_below(root) and not os.path.isfile(root)
        )
    if blocked:
        print(REASON, file=sys.stderr)
        sys.exit(2)


main()
