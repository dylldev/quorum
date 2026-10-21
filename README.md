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
| `bin/quorum-cleanup` | runs each provider's cleanup command and `quorum-doctor --fix` |
| `bin/quorum-doctor` | the universal cache check: sizes, known leaks, safe `--fix`, `--schedule` |

## Providers (no setup for the common ones)
`providers.catalog.json` ships 40 ready-made providers; `quorum-ask <provider> ...` finds them even if your config does not list them. API keys come from environment variables, never from files.
- **CLIs:** codex, claude, gemini-cli, qwen-code, cursor-agent, copilot-cli, amp, goose, aider, opencode, llm, mods, ollama, llama-cpp
- **OpenAI-compatible APIs:** openai, openrouter, groq, together, fireworks, deepseek, mistral, xai, cerebras, sambanova, perplexity, nvidia-nim, moonshot-kimi, zhipu-glm, minimax, dashscope-qwen, siliconflow, huggingface
- **Local servers:** lmstudio, vllm, ollama-http, localai
- **Other formats:** anthropic-api, gemini-api
- **Anything odd or self-hosted:** `custom-openai` / `custom-anthropic` read the URL from `QUORUM_CUSTOM_BASE` (and the key from `QUORUM_CUSTOM_KEY`). Or add your own entry to `quorum.json`: a provider is only a command template.
Only `codex` and `opencode` have been run by the author (`"verified": true`); the others use the vendors' documented flags and URLs, so run `quorum-probe` after adding one. `quorum-http` (standard-library Python) speaks the OpenAI, Anthropic and Gemini wire formats and is tested against a local fake server.

## Cache protection (so quorum never fills your disk)
AI command-line tools leave data behind: Codex once leaked 42 GB of plugin-marketplace copies, and opencode keeps every session forever. quorum protects you in four layers:
1. **Private scratch:** every run gets its own `TMPDIR`, deleted when the run ends, so anything a runner parks in the temp folder disappears.
2. **Disk guard:** `quorum-ask` refuses to start when free disk is below `limits.minFreeGB` (default 3 GB).
3. **Growth watch:** after each run it measures the runner's data folders (`watch` in the catalog or your config), warns when a single run grew one by more than `limits.growthWarnMB` (default 200 MB) and appends to `~/.local/state/quorum/growth.log`.
4. **`quorum-doctor`:** lists the known leak spots (`leaks` in the catalog) with sizes; `--fix` deletes only entries that match a listed pattern, are older than the listed age, and whose tool is not running. `--schedule` prints a ready-made hourly launchd/cron job. `quorum-cleanup` runs provider cleanups plus `quorum-doctor --fix`.
Add your own tool's leaks to `quorum.json` under `"leaks": [{"tool","why","path","glob","minAgeMinutes","skipIfRunning"}]` and `"watch": {"tool": ["~/path"]}`.

## The free-only guard is a naming filter
`freeOnly` + `freeNameMatch` makes `quorum-ask` refuse any model whose whole name does not match the pattern (opencode's `-free` models, OpenRouter's `:free`), and a `freeOnly` provider with no pattern refuses everything. It stops typos and accidental paid picks; it cannot know a provider's billing, so check pricing yourself.

## Security notes
- Model names, efforts and tags are checked against a strict character set and reach the command as environment variables, never as shell source.
- A `./quorum.json` in a project is ignored unless you set `QUORUM_TRUST_PROJECT=1` (a config can run commands). An explicit `QUORUM_CONFIG` must exist.
- `quorum-http` never follows redirects, refuses to send a key over plain http (except localhost), redacts the key in errors and writes private (0600) output files.
- Timeouts kill the whole process group, so no orphaned runners keep billing.
- CLI providers receive the prompt as a command-line argument, which other users on the machine can see in `ps`. For sensitive prompts use an HTTP provider (`quorum-http` reads the prompt from a file) or a CLI that reads stdin.
- Cleanup only deletes things quorum created (sessions titled `quorum-<tag>-<pid>` whose process has ended; Codex marketplace clones older than 30 minutes while no `codex exec` runs).
- macOS and Linux with bash and Python 3. Windows is not supported (use WSL).

## Config
See `quorum.example.json`. Placeholders in a provider command: `{model} {effort} {prompt} {out} {tag}`. Optional `afterRun` and `cleanup` commands remove sessions and caches the tool leaves behind. Needs bash and Python 3 (no Perl).

## Test
`bash tests/run.sh` (uses a fake provider; no network, no accounts).

License: Apache-2.0.
