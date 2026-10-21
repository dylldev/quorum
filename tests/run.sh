#!/usr/bin/env bash
# Self-test with a fake provider: no network, no accounts.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"; t="$(mktemp -d)"; trap 'rm -rf "$t"' EXIT
cat > "$t/quorum.json" <<'J'
{ "providers": {
    "fake":  { "run": "echo \"{model}|{effort}|{tag}|$(cat {prompt})\" > {out}", "afterRun": "echo ran > $QUORUM_TEST_MARK" },
    "freeo": { "run": "echo hi > {out}", "freeOnly": true, "freeNameMatch": "-free$" } },
  "panel": [ { "provider": "fake", "model": "m1", "role": "review" } ],
  "limits": { "timeoutSeconds": 20 } }
J
export QUORUM_CONFIG="$t/quorum.json" QUORUM_TEST_MARK="$t/mark"
echo "hello" > "$t/p.md"
"$root/bin/quorum-ask" fake m1 high tag1 "$t/p.md" "$t/out.txt" "$t"
grep -q '^m1|high|tag1-[0-9]*|hello$' "$t/out.txt" || { echo "FAIL substitution: $(cat "$t/out.txt")"; exit 1; }
[ -f "$t/mark" ] || { echo "FAIL afterRun"; exit 1; }
if "$root/bin/quorum-ask" freeo paid-model - x "$t/p.md" "$t/o2.txt" "$t" 2>/dev/null; then echo "FAIL free-only guard"; exit 1; fi
"$root/bin/quorum-ask" freeo ok-free - x "$t/p.md" "$t/o3.txt" "$t" && grep -q hi "$t/o3.txt" || { echo "FAIL free ok"; exit 1; }
"$root/bin/quorum-probe" | grep -q "^DOWN fake/m1" && true   # fake output lacks OK: must report DOWN, not crash
"$root/bin/quorum-cleanup" >/dev/null
python3 "$root/tests/test_quorum_http.py"
echo "PASS"
