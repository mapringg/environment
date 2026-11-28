# AGENTS.md

## Rules

- Use Opus 5.5 (effort high) and GPT-6.2 Sol (reasoningEffort high) for council.
- Use Gemini 4 Neon (thought_level high) as the third council member.
- If one council member is quota-limited, run council with the other two and name the missing one. If two are out, stop and report.
- Cap council at 3 rounds. Stop early when a round has only nits.
- Use GPT-6.2 Sol (reasoningEffort high) for sol-loop review.
- Consult Claude Fable 5.2 (effort high) read-only when stuck or planning a large change.
- Use linked T3 environments to delegate to `apple` or `desktop`. Ubuntu is the hub.
- Find fleet instructions and the wake helper in `~/code/mapringg/environment`.
- Use `desktop wake`, `desktop suspend`, and `desktop windows` for desktop power.
- Check for active work before suspending or rebooting `desktop`.
- Name branches `mapring/<kebab-case summary>`. Rename placeholders with `git branch -m`.

## Sources

- Use [PR writing](https://github.com/mapringg/standard/blob/v1.13.0/.claude/skills/pr/SKILL.md) when writing a pull request.
- Follow [Capture](https://github.com/mapringg/standard/blob/v1.13.0/.claude/skills/capture/SKILL.md) when preparing pull request evidence.
- Follow [Environment setup](.claude/skills/setup-environment/SKILL.md) when installing or syncing.
- Follow [Desktop power](.claude/skills/setup-environment/SKILL.md#desktop-power) for desktop power.
