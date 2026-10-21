---
name: verify
description: Use before believing or acting on another model's or agent's claim ("tests pass", "bug fixed", "this API exists", "I reviewed everything"), and before saying work is done. Turns every claim into a check you actually ran, and keeps a short claim ledger.
---

# Verify

Never repeat a claim you did not check. For each claim from an agent (or yourself):
1. Write it as a testable sentence.
2. Pick the cheapest real check: run the test, build, grep the symbol, open the file at the line, diff the tree, call the endpoint. Linters are not compilers are not tests.
3. Run it fresh, read the full output and exit code.
4. Record: `claim | check | result | evidence (command or file:line)`. Result is one of verified, refuted, unverified.
5. Refuted or unverified claims never go in the final report as facts. Say "unverified" plainly.
Special cases: another agent's "all tests pass" needs your own run; "I fixed X" needs a test that fails before and passes after (revert the fix to prove it); "this library function exists" needs a grep or a doc lookup; a count ("12 files changed") needs the command that printed it.
Also check the negative: what did the agent not look at? Ask for the list of files it actually read.
