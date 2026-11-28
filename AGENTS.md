# AGENTS.md

## Rules

- Use Opus 5.5 (effort high) and GPT-6.2 Sol (reasoningEffort high) for council.
- Use Gemini 4 Neon (thought_level high) as the third council member.
- Use GPT-6.2 Sol (reasoningEffort high) for sol-loop review.
- Use linked T3 environments to delegate to `apple` or `desktop`. Ubuntu is the hub.
- Find fleet instructions and the wake helper in `~/code/mapringg/environment`.
- Wake `desktop` from `ubuntu` with `bin/wake-desktop` and the MAC stored in 1Password.
- Check for active work before suspending `desktop`. Run `systemctl suspend` there.

## Sources

- Use [PR writing](https://github.com/mapringg/standard/blob/v1.13.0/.claude/skills/pr/SKILL.md) when writing a pull request.
- Follow [Capture](https://github.com/mapringg/standard/blob/v1.13.0/.claude/skills/capture/SKILL.md) when preparing pull request evidence.
- Follow [Environment setup](.claude/skills/setup-environment/SKILL.md) when installing or syncing.
- Follow [Desktop power](.claude/skills/setup-environment/SKILL.md#desktop-power) when waking or suspending.
