#!/usr/bin/env bash
# Self-test with fake providers: no network, no accounts.
set -uo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"; t="$(mktemp -d)"; trap 'rm -rf "$t"' EXIT
fail() { echo "FAIL: $*"; exit 1; }
cat > "$t/quorum.json" <<'J'
{ "providers": {
    "fake":  { "run": "echo \"{model}|{effort}|{tag}|$(cat {prompt})\" > {out}", "afterRun": "echo ran > \"$QUORUM_TEST_MARK\"" },
    "freeo": { "run": "echo hi > {out}", "freeOnly": true, "freeNameMatch": ".*-free" },
    "nomatch": { "run": "echo hi > {out}", "freeOnly": true },
    "sleepy": { "run": "sleep 30 & echo $! > \"$QUORUM_TEST_PIDFILE\"; wait" },
    "okbot": { "run": "echo OK > {out}" }, "chatty": { "run": "echo 'NOT OK, sorry' > {out}" }, "failer": { "run": "echo OK > {out}; exit 3" } },
  "panel": [ { "provider": "okbot", "model": "a/b", "role": "r" }, { "provider": "chatty", "model": "c", "role": "r" },
             { "provider": "failer", "model": "d", "role": "r" } ],
  "limits": { "timeoutSeconds": 20 } }
J
export QUORUM_CONFIG="$t/quorum.json" QUORUM_TEST_MARK="$t/mark" QUORUM_TEST_PIDFILE="$t/pid"
echo "hello" > "$t/p.md"; ask="$root/bin/quorum-ask"

"$ask" fake m1 high tag1 "$t/p.md" "$t/out.txt" "$t" || fail "basic run"
grep -q '^m1|high|tag1-[0-9]*|hello$' "$t/out.txt" || fail "substitution: $(cat "$t/out.txt")"
[ -f "$t/mark" ] || fail "afterRun"
[ "$(stat -f %Lp "$t/out.txt" 2>/dev/null || stat -c %a "$t/out.txt")" = "600" ] || fail "output must be private (0600)"
( cd "$t" && "$ask" fake m1 high tag1 p.md rel.txt . ) && [ -f "$t/rel.txt" ] || fail "relative paths"

# injection: a model name that is shell source must be refused outright, and never executed
"$ask" fake 'x$(touch '"$t"'/pwned)-free' - tag "$t/p.md" "$t/o.txt" "$t" 2>/dev/null && fail "unsafe model accepted"
[ ! -e "$t/pwned" ] || fail "INJECTION EXECUTED"
"$ask" fake 'ok-model' - 'bad tag;x' "$t/p.md" "$t/o.txt" "$t" 2>/dev/null && fail "unsafe tag accepted"

# free-only is a naming filter, matched in full; an empty filter refuses everything
"$ask" freeo paid-model - x "$t/p.md" "$t/o2.txt" "$t" 2>/dev/null && fail "free guard let a paid-looking name through"
"$ask" freeo 'ok-free' - x "$t/p.md" "$t/o3.txt" "$t" && grep -q hi "$t/o3.txt" || fail "free model refused"
"$ask" nomatch anything - x "$t/p.md" "$t/o4.txt" "$t" 2>/dev/null && fail "freeOnly without a filter must refuse"

# timeout kills the whole process group (no orphaned children)
QUORUM_TIMEOUT=2 "$ask" sleepy m - x "$t/p.md" "$t/o5.txt" "$t" 2>/dev/null; rc=$?
[ "$rc" = 124 ] || fail "timeout exit code $rc"
sleep 0.5; kill -0 "$(cat "$t/pid")" 2>/dev/null && fail "child survived the timeout"

# project config must not be picked up automatically
mkdir "$t/proj"; echo '{"providers":{"evil":{"run":"touch '"$t"'/evil"}}}' > "$t/proj/quorum.json"
( cd "$t/proj" && env -u QUORUM_CONFIG HOME="$t/nohome" "$ask" evil m - x "$t/p.md" "$t/o6.txt" "$t/proj" 2>/dev/null ) && fail "untrusted ./quorum.json ran"
[ ! -e "$t/evil" ] || fail "untrusted config executed a command"
QUORUM_CONFIG="$t/missing.json" "$ask" fake m - x "$t/p.md" "$t/o7.txt" 2>/dev/null && fail "missing explicit config must be an error"

# probe: exact OK only, exit status matters, slash in model name is fine
out="$("$root/bin/quorum-probe")"
echo "$out" | grep -q "^up   okbot/a/b$" || fail "probe up: $out"
echo "$out" | grep -q "^DOWN chatty/c$" || fail "probe must reject 'NOT OK': $out"
echo "$out" | grep -q "^DOWN failer/d$" || fail "probe must reject a failing runner: $out"

"$root/bin/quorum-cleanup" >/dev/null || fail "cleanup"

# universal cache protection: disk guard, private per-run TMPDIR, doctor deletes only old matching entries
QUORUM_MIN_FREE_GB=999999 "$ask" fake m - x "$t/p.md" "$t/o8.txt" "$t" 2>/dev/null; [ $? = 7 ] || fail "disk guard must refuse when disk is too full"
cat > "$t/q2.json" <<'J'
{ "providers": { "tmpwriter": { "run": "dd if=/dev/zero of=\"$TMPDIR/big\" bs=1m count=5 2>/dev/null; echo \"$TMPDIR\" > {out}" } } }
J
QUORUM_CONFIG="$t/q2.json" "$ask" tmpwriter m - x "$t/p.md" "$t/o9.txt" "$t" || fail "tmpwriter"
[ ! -e "$(cat "$t/o9.txt")" ] || fail "per-run TMPDIR must be deleted after the run"
mkdir -p "$t/home/.codex/.tmp/marketplaces/.staging/marketplace-upgrade-old" "$t/home/.codex/.tmp/marketplaces/.staging/marketplace-upgrade-new" "$t/home/.codex/.tmp/marketplaces/.staging/keepme"
touch -t 202001010000 "$t/home/.codex/.tmp/marketplaces/.staging/marketplace-upgrade-old" "$t/home/.codex/.tmp/marketplaces/.staging/keepme"
HOME="$t/home" QUORUM_ASSUME_IDLE=1 QUORUM_CONFIG="$t/q2.json" "$root/bin/quorum-doctor" | grep -q "would delete" || fail "doctor dry run should report"
[ -d "$t/home/.codex/.tmp/marketplaces/.staging/marketplace-upgrade-old" ] || fail "doctor deleted without --fix"
HOME="$t/home" QUORUM_ASSUME_IDLE=1 QUORUM_CONFIG="$t/q2.json" "$root/bin/quorum-doctor" --fix >/dev/null
[ ! -e "$t/home/.codex/.tmp/marketplaces/.staging/marketplace-upgrade-old" ] || fail "doctor --fix must delete the old leak"
[ -d "$t/home/.codex/.tmp/marketplaces/.staging/marketplace-upgrade-new" ] || fail "doctor must keep young entries"
[ -d "$t/home/.codex/.tmp/marketplaces/.staging/keepme" ] || fail "doctor must keep entries that do not match the pattern"
python3 "$root/tests/test_quorum_http.py" || fail "http tests"
echo "PASS"
