#!/usr/bin/env bash
set -uo pipefail

# run-invariant.sh — runs python ortho32_invariant.py, returns { entropy, variance, runs, trace_hash }

if [ -z "${ORTHO_REPO_PATH:-}" ] || [ ! -d "$ORTHO_REPO_PATH" ]; then
  echo '{"error":"ORTHO_REPO_PATH not set or directory not found","entropy":0,"variance":0,"runs":0,"trace_hash":""}'
  exit 0
fi

INV_PY=""
for p in "$ORTHO_REPO_PATH/ortho32_invariant.py" "$ORTHO_REPO_PATH/invariant/ortho32_invariant.py" "$ORTHO_REPO_PATH/scripts/ortho32_invariant.py" "$ORTHO_REPO_PATH/ortho32/invariant.py"; do
  if [ -f "$p" ]; then INV_PY="$p"; break; fi
done

if [ -z "$INV_PY" ]; then
  echo '{"error":"ortho32_invariant.py not found","entropy":0,"variance":0,"runs":0,"trace_hash":""}'
  exit 0
fi

OUTPUT=""
STATUS=0
OUTPUT=$(python3 "$INV_PY" 2>&1) || STATUS=$?

python3 - "$OUTPUT" "$STATUS" << 'PY'
import sys, json, re
output = sys.argv[1] if len(sys.argv) > 1 else ""
status = sys.argv[2] if len(sys.argv) > 2 else "0"
# Try JSON direct
try:
    j=json.loads(output)
    if isinstance(j, dict) and "entropy" in j:
        print(json.dumps({"entropy": j.get("entropy",0), "variance": j.get("variance",0), "runs": j.get("runs",0), "trace_hash": j.get("trace_hash", j.get("traceHash",""))}))
        sys.exit(0)
except: pass
# Parse text output
entropy = 0
variance = 0
runs = 0
trace_hash = ""
m = re.search(r'entropy["\s:]+([0-9.]+)', output, re.I)
if m: entropy = float(m.group(1))
m = re.search(r'variance["\s:]+([0-9.]+)', output, re.I)
if m: variance = float(m.group(1))
m = re.search(r'runs["\s:]+([0-9]+)', output, re.I)
if m: runs = int(m.group(1))
m = re.search(r'trace_hash["\s:]+([a-fA-F0-9]{16,})', output)
if m: trace_hash = m.group(1)
else:
    m = re.search(r'traceHash["\s:]+([a-fA-F0-9]{16,})', output)
    if m: trace_hash = m.group(1)

result = {"entropy": entropy, "variance": variance, "runs": runs, "trace_hash": trace_hash}
if status != "0":
    result["error"] = output[:2000]
print(json.dumps(result))
PY
