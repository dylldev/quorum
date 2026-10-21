---
name: hygiene
description: Use after any round of running AI command-line tools, when disk space drops, or when a machine feels slow: finds and removes the scratch, cache and session data that agent tools leave behind, without touching the user's own work. Learned from a 42 GB leak.
---

# Hygiene

Agent CLIs leave data behind. Measure first, delete only what you can name and explain. If the quorum plugin is installed, run `quorum-doctor` (sizes and known leaks, nothing deleted) and `quorum-doctor --fix` (deletes only old, pattern-matched leaks while the tool is not running).
1. `df -h /` and `du -sh` on the usual suspects: `~/.codex` (and `~/.codex/.tmp`), `~/.local/share/opencode` (the `opencode.db` file), `~/.claude/projects`, `~/Library/Developer/Xcode/DerivedData`, `~/Library/Developer/CoreSimulator`, `~/.cache`, the system temp folder.
2. Know the known leaks: Codex plugin-marketplace clones (`.codex/.tmp/marketplaces/.staging/marketplace-upgrade-*`, ~0.45 GB each, leaked when a run exits early; avoid with `--ephemeral --disable plugins`); opencode sessions (every file the agent read is stored; delete the sessions you created with `opencode session delete`, then `VACUUM` the database when nothing is running).
3. Delete only: things this workflow created (tagged sessions, scratch worktrees, probe outputs) and caches that rebuild themselves. Never delete the user's chats, other tools' sessions, keys or project files; list what you will delete and the size first when in doubt.
4. Report before and after (free disk, sizes) in plain words.
Schedule it if the leak is recurring (a small launchd/cron job that only runs while no agent is running).
