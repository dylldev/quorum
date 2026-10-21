"""Tests quorum-http against a local fake server speaking all three formats."""
import json, os, subprocess, sys, tempfile, threading
from http.server import BaseHTTPRequestHandler, HTTPServer
class H(BaseHTTPRequestHandler):
    def do_POST(self):
        body=json.loads(self.rfile.read(int(self.headers["Content-Length"])))
        if self.path.startswith("/fail"):
            self.send_response(401); self.end_headers(); self.wfile.write(b'{"error":"bad key sekret"}'); return
        if self.path.endswith("/chat/completions"):
            assert self.headers["Authorization"]=="Bearer sekret"; out={"choices":[{"message":{"content":"openai says "+body["messages"][0]["content"]}}]}
        elif self.path=="/v1/messages":
            assert self.headers["x-api-key"]=="sekret"; out={"content":[{"type":"text","text":"anthropic says "+body["messages"][0]["content"]}]}
        elif ":generateContent" in self.path:
            assert self.headers["x-goog-api-key"]=="sekret"; out={"candidates":[{"content":{"parts":[{"text":"gemini says "+body["contents"][0]["parts"][0]["text"]}]}}]}
        elif self.path=="/fail":
            self.send_response(401); self.end_headers(); self.wfile.write(b'{"error":"bad key sekret"}'); return
        else:
            self.send_response(404); self.end_headers(); return
        data=json.dumps(out).encode(); self.send_response(200); self.send_header("Content-Length",str(len(data))); self.end_headers(); self.wfile.write(data)
    def log_message(self,*a): pass
srv=HTTPServer(("127.0.0.1",0),H); port=srv.server_port; threading.Thread(target=srv.serve_forever,daemon=True).start()
tool=os.path.join(os.path.dirname(__file__),"..","bin","quorum-http"); d=tempfile.mkdtemp(); p=os.path.join(d,"p"); open(p,"w").write("hi")
env=dict(os.environ,TESTKEY="sekret",QUORUM_TEST_BASE=f"http://127.0.0.1:{port}")
def run(fmt,base,key="TESTKEY"):
    o=os.path.join(d,"o"); r=subprocess.run([tool,fmt,base,key,"m",p,o],env=env); return r.returncode, open(o).read() if os.path.exists(o) else ""
base=f"http://127.0.0.1:{port}"
assert run("openai",base)==(0,"openai says hi\n"), run("openai",base)
assert run("anthropic",base)==(0,"anthropic says hi\n")
assert run("gemini",base)==(0,"gemini says hi\n")
assert run("openai","env:QUORUM_TEST_BASE")==(0,"openai says hi\n")                    # odd/self-hosted base via env
rc,out=run("openai",base+"/fail-x"); assert rc==5 and "sekret" not in out, (rc,out)    # HTTP error: nonzero, key never echoed
rc,out=run("openai",base,"MISSING_KEY"); assert rc==4, (rc,out)                        # missing key refused before any request
print("PASS http")
