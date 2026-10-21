---
name: quorum
description: Use for any non-trivial request (feature, fix, audit, merge, release, design decision): get several different AI models to agree before anything ships. Plan with a strong model first, hand the agreed plan to a panel of cheaper or free models, review their output against the real code, and loop until you and the strong model agree. Models are chosen per moment from the user's quorum.json, so nothing is tied to one vendor.
---

# Quorum

One model can be confidently wrong. Several different models, checked against the real code, are much harder to fool. This skill is a procedure plus three small scripts (`quorum-ask`, `quorum-probe`, `quorum-cleanup`, in the plugin's `bin/`).

## Setup (once)
Copy `quorum.example.json` to `~/.config/quorum/quorum.json` (a project `./quorum.json` is only read with `QUORUM_TRUST_PROJECT=1`). It has three parts:
- **providers**: a command template per model runner (`{model} {effort} {prompt} {out} {tag}` are filled in). Add any CLI: Codex, opencode, `claude -p`, ollama, llama.cpp, a curl wrapper. Nothing is forced to be free. If the user wants a no-spend rule they set `freeOnly` (all providers) or `freeOnlyProviders` in the config; `freeNameMatch` then refuses models whose whole name does not match (a naming filter, not a billing guarantee). Respect whatever the config says; never turn the rule on or off yourself.
- **moments**: which model to use when (`bigDecision`, `plan`, `reviewDiff`, `quickCheck`). Put the strongest model on the rare big decisions, a solid workhorse on plans and diff reviews, a fast cheap one on quick checks.
- **panel**: the cheap or free models, each with a role (implement, review, audit). Keep at least `limits.minPanelSize` different ones.

## Every session
1. `quorum-probe`: shows which panel models answer right now. Models disappear and rate-limit; never trust an old list. Tell the user which are down.
2. If the user has a usage meter for a paid provider, check it before adding runs; stop adding runs near the limit and say so.

## The cycle
1. **Brief.** Write goal, constraints, files, verified vs unverified to a file.
2. **Plan with the strong model.** `quorum-ask <provider> <model> <effort> plan brief.md plan.out`, using the `plan` moment (or `bigDecision` for real architecture questions). Make your own plan too.
3. **Agree.** Compare plans. Where they differ, send each side's reasons to the other and iterate. Write the agreed plan (decisions, order, risks, how to verify).
4. **Panel.** Send the agreed plan to at least `minPanelSize` different panel models in parallel (one background command each): `quorum-ask <provider> <model> - <tag> plan.md out-<model>.txt <project dir>`. Say whether they may edit files; default read-only. If they write code, give each its own git worktree.
5. **Review together.** You and the strong model check the panel's output against the real code (build, tests, diff). A claim nobody checked is "unverified". Weigh claims across models, but a lone finding that is specific and checkable still gets checked; the majority can be wrong too. Loop until you and the strong model agree.
6. **You finish.** Tests first (red then green), real checks, plain report. Anything outward-facing (publish, push, release, delete, install, credentials) stays with you and the user.
7. **Clean up.** `quorum-cleanup`.

## Rules
- Models are advisers, not authorities. Verify against the code.
- No secrets or personal data in briefs or prompts.
- Report rate limits, usage limits, removed models and errors to the user immediately.
- Before publishing or merging, fetch the remote and look at what is there; never overwrite work that exists only on the remote. Prefer the platform-neutral way of merging that keeps the user's author identity private.
- Do not give agents a whole repo to read when a diff or file list will do: session size is the size of what they read.
