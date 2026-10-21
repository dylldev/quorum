---
name: handoff
description: Use when work must continue in another AI session or tool (usage running out, switching models, a cloud agent, a teammate). Writes one self-contained prompt file with the project, rules, current state, exact commands, what is done and verified, what is left, and what the next agent must NOT do.
---

# Handoff

The next agent has zero context. Write one file (default `HANDOFF.md` outside the repo or in a gitignored spot) with:
1. **Project in 5 lines** and where it lives (paths, branch, remotes). Which branch is real; which is stale.
2. **Rules that bit us** (publishing, authors, secrets, free-only models, things never to run).
3. **Commands that work** (build, test, run), copied from this session and verified, not remembered.
4. **State**: done and verified (with the evidence), done but unverified, in progress (files, branch, worktree), blocked and why.
5. **Next steps in order**, each with how to verify it is done.
6. **Do-not list** and who may do outward-facing actions.
7. **Where more history lives** (transcripts, notes, ledgers).
Then give the user a short paste-in prompt that points at the file. If one agent runs locally and another in the cloud, say which tasks belong to which (anything touching the user's machine, devices, keys or publishing is local only). Never include secrets.
