"""Shared helpers for the quorum scripts. Standard library only."""
import json, os, re, subprocess, signal, sys, time

HERE = os.path.dirname(os.path.abspath(__file__))
CATALOG = os.path.join(HERE, "..", "providers.catalog.json")
SAFE_NAME = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._:/@+\-]{0,199}$")   # model names, efforts, tags: data only, never shell source
SAFE_TAG = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._\-]{0,59}$")
PLACEHOLDERS = {"{model}": "QUORUM_MODEL", "{effort}": "QUORUM_EFFORT", "{tag}": "QUORUM_TAG",
                "{prompt}": "QUORUM_PROMPT", "{out}": "QUORUM_OUT", "{bin}": "QUORUM_BIN"}

def die(msg, code=2):
    print("quorum: " + msg, file=sys.stderr); sys.exit(code)

def find_config():
    """Explicit QUORUM_CONFIG must exist. A ./quorum.json in the project is only used when QUORUM_TRUST_PROJECT=1,
    because a config can run commands and an untrusted checkout must not."""
    explicit = os.environ.get("QUORUM_CONFIG")
    if explicit:
        if not os.path.isfile(explicit): die(f"QUORUM_CONFIG points at a missing file: {explicit}")
        return explicit
    if os.environ.get("QUORUM_TRUST_PROJECT") == "1" and os.path.isfile("quorum.json"): return "quorum.json"
    home = os.path.expanduser("~/.config/quorum/quorum.json")
    if os.path.isfile(home): return home
    if os.path.isfile("quorum.json"):
        die("found ./quorum.json but it runs commands: review it, then set QUORUM_TRUST_PROJECT=1 to use it "
            "(or copy it to ~/.config/quorum/quorum.json)")
    die("no config: copy quorum.example.json to ~/.config/quorum/quorum.json")

def load_json(path):
    try:
        with open(path, encoding="utf-8") as f: return json.load(f)
    except (OSError, ValueError) as e:
        die(f"cannot read {path}: {e}")

def providers(cfg):
    """User providers win as whole entries (fields are never mixed with the catalog's); the catalog fills the rest."""
    merged = {}
    if os.path.isfile(CATALOG): merged.update(load_json(CATALOG).get("providers", {}))
    user = cfg.get("providers", {})
    if not isinstance(user, dict): die("config 'providers' must be an object")
    merged.update(user)
    return merged

def shell_template(tpl):
    """{model} etc. become quoted environment references, so values are data and can never inject shell code."""
    for ph, var in PLACEHOLDERS.items(): tpl = tpl.replace(ph, f'"${var}"')
    return tpl

def free_ok(cfg, name, provider_cfg, model):
    """Optional rule, off by default. Active when the provider has freeOnly, the config has freeOnly:true, or the provider is
    listed in freeOnlyProviders. It is a NAMING filter, not a billing guarantee: the whole model name must match freeNameMatch.
    Providers marked "free": true (local runners) always pass."""
    required = bool(provider_cfg.get("freeOnly")) or bool(cfg.get("freeOnly")) or name in (cfg.get("freeOnlyProviders") or [])
    if not required or provider_cfg.get("free"): return True
    pat = provider_cfg.get("freeNameMatch")
    return bool(pat) and re.fullmatch(pat, model) is not None

def run_limited(cmd, env, cwd, timeout):
    """Run `bash -c cmd` in its own process group; on timeout kill the whole group. Returns the exit code (124 on timeout)."""
    p = subprocess.Popen(["bash", "-c", cmd], env=env, cwd=cwd, start_new_session=True,
                         stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    try:
        return p.wait(timeout=timeout)
    except subprocess.TimeoutExpired:
        try: os.killpg(p.pid, signal.SIGKILL)
        except ProcessLookupError: pass
        p.wait(); return 124

def pid_alive(pid):
    try: os.kill(int(pid), 0); return True
    except (ProcessLookupError, ValueError): return False
    except PermissionError: return True

def expand(path):
    return os.path.expandvars(os.path.expanduser(path)).replace("$TMPDIR", os.environ.get("TMPDIR", "/tmp"))

def free_gb(path="/"):
    import shutil
    return shutil.disk_usage(path).free / 1e9

def dir_mb(path):
    """Size of a folder in MB via du (fast, handles huge trees); 0 if it does not exist."""
    path = expand(path)
    if not os.path.exists(path): return 0.0
    try:
        out = subprocess.run(["du", "-sk", path], capture_output=True, text=True, timeout=60).stdout.split()
        return int(out[0]) / 1024 if out else 0.0
    except Exception:
        return 0.0

def running(pattern):
    if os.environ.get("QUORUM_ASSUME_IDLE") == "1": return False      # tests only
    try:
        return subprocess.run(["pgrep", "-f", pattern], capture_output=True).returncode == 0
    except FileNotFoundError:
        return False

def state_dir():
    d = os.path.expanduser("~/.local/state/quorum"); os.makedirs(d, exist_ok=True); return d
