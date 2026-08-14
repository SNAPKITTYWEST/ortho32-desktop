#!/usr/bin/env bash
set -uo pipefail

# replay.sh — runs deterministic replay, returns { cycles, trace_hash, final_state_hash }

if [ -z "${ORTHO_REPO_PATH:-}" ] || [ ! -d "$ORTHO_REPO_PATH" ]; then
  echo '{"error":"ORTHO_REPO_PATH not set or directory not found","cycles":0,"trace_hash":"","final_state_hash":""}'
  exit 0
fi

REPLAY_PY=""
for p in "$ORTHO_REPO_PATH/replay.py" "$ORTHO_REPO_PATH/scripts/replay.py" "$ORTHO_REPO_PATH/trace/replay.py" "$ORTHO_REPO_PATH/ortho32_replay.py"; do
  if [ -f "$p" ]; then REPLAY_PY="$p"; break; fi
done

if [ -z "$REPLAY_PY" ]; then
  # Try binary replay tool
  if [ -f "$ORTHO_REPO_PATH/build/replay" ]; then
    OUT=$("$ORTHO_REPO_PATH/build/replay" 2>&1 || true)
    python3 - "$OUT" << 'PY'
import sys, json, re
o=sys.argv[1]
try:
 j=json.loads(o)
 print(json.dumps({"cycles": j.get("cycles",0), "trace_hash": j.get("trace_hash", j.get("traceHash","")), "final_state_hash": j.get("final_state_hash", j.get("finalStateHash",""))}))
except:
 m1=re.search(r'cycles["\s:]+([0-9]+)',o)
 m2=re.search(r'trace_hash["\s:]+([a-fA-F0-9]+)',o)
 m3=re.search(r'final_state_hash["\s:]+([a-fA-F0-9]+)',o)
 print(json.dumps({"cycles": int(m1.group(1)) if m1 else 0, "trace_hash": m2.group(1) if m2 else "", "final_state_hash": m3.group(1) if m3 else ""}))
PY
    exit 0
  fi
  echo '{"error":"replay script not found","cycles":0,"trace_hash":"","final_state_hash":""}'
  exit 0
fi

OUTPUT=""
STATUS=0
OUTPUT=$(python3 "$REPLAY_PY" 2>&1) || STATUS=$?

python3 - "$OUTPUT" "$STATUS" << 'PY'
import sys, json, re
output = sys.argv[1] if len(sys.argv) > 1 else ""
status = sys.argv[2] if len(sys.argv) > 2 else "0"
try:
    j=json.loads(output)
    if isinstance(j, dict) and ("cycles" in j or "trace_hash" in j):
        print(json.dumps({"cycles": j.get("cycles",0), "trace_hash": j.get("trace_hash", j.get("traceHash","")), "final_state_hash": j.get("final_state_hash", j.get("finalStateHash",""))}))
        sys.exit(0)
except: pass
cycles=0
th=""
fsh=""
m=re.search(r'cycles["\s:]+([0-9]+)',output)
if m: cycles=int(m.group(1))
m=re.search(r'trace_hash["\s:]+([a-fA-F0-9]{16,})',output)
if m: th=m.group(1)
else:
 m=re.search(r'traceHash["\s:]+([a-fA-F0-9]{16,})',output)
 if m: th=m.group(1)
m=re.search(r'final_state_hash["\s:]+([a-fA-F0-9]{16,})',output)
if m: fsh=m.group(1)
else:
 m=re.search(r'finalStateHash["\s:]+([a-fA-F0-9]{16,})',output)
 if m: fsh=m.group(1)
result={"cycles": cycles, "trace_hash": th, "final_state_hash": fsh}
if status!="0":
 result["error"]=output[:2000]
print(json.dumps(result))
PY
