# quorum

Make several AI models agree before you ship.

Plan with a strong model, let a panel of cheaper or free models do the legwork, check everything against the real code, and loop until you and the strong model agree. Vendor-neutral: every model runner is a command template in one JSON file (Codex, opencode, `claude -p`, Ollama, anything with a CLI).

## Install (Claude Code)
```
/plugin marketplace add dylldev/quorum
/plugin install quorum@quorum
```
Then copy `quorum.example.json` to `~/.config/quorum/quorum.json` and edit the providers, moments and panel to the tools you have. Run `bin/quorum-probe` to see which panel models are alive.

## What is in it
| Piece | What it does |
|---|---|
| skill `quorum` | the procedure: brief, plan with the strong model, agree, panel, review, verify, clean up |
| skill `handoff` | writes a self-contained prompt so another session or agent can continue |
| skill `verify` | turns agent claims into checks you actually ran, with a claim ledger |
| skill `hygiene` | finds and removes the cache and scratch data agent tools leave behind |
| `bin/quorum-ask` | runs one model from your config (timeout, free-only guard, session cleanup) |
| `bin/quorum-probe` | checks which panel models answer right now |
| `bin/quorum-cleanup` | runs each provider's cleanup command |

## Why the free-only guard
`freeOnly` + `freeNameMatch` on a provider makes `quorum-ask` refuse any model whose name does not match (for example opencode's `-free` models), so a typo can never spend money.

## Config
See `quorum.example.json`. Placeholders in a provider command: `{model} {effort} {prompt} {out} {tag}`. Optional `afterRun` and `cleanup` commands remove sessions and caches the tool leaves behind. Needs bash and python3.

## Test
`bash tests/run.sh` (uses a fake provider; no network, no accounts).

License: Apache-2.0.
