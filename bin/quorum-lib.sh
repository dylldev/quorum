# Shared helpers. Needs python3 (JSON), nothing else.
quorum_config() {
  for f in "${QUORUM_CONFIG:-}" "./quorum.json" "$HOME/.config/quorum/quorum.json"; do
    [ -n "$f" ] && [ -f "$f" ] && { echo "$f"; return 0; }
  done
  return 1
}
# quorum_get <file> <jq-like path>: tiny path reader, e.g. .providers["codex"].run  or .limits.timeoutSeconds
quorum_get() {
  python3 - "$1" "$2" <<'PY'
import json,sys,re
d=json.load(open(sys.argv[1])); path=sys.argv[2]
cur=d
for m in re.finditer(r'\.([A-Za-z_][\w-]*)|\["([^"]+)"\]', path):
    k=m.group(1) or m.group(2)
    if isinstance(cur,dict) and k in cur: cur=cur[k]
    else: cur=None; break
if cur is None: print("")
elif isinstance(cur,bool): print("true" if cur else "false")
elif isinstance(cur,(dict,list)): print(json.dumps(cur))
else: print(cur)
PY
}
