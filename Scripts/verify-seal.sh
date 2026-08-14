#!/usr/bin/env bash
set -uo pipefail

# verify-seal.sh — runs python seal/seal.py verify, returns { chain_ok, entries:[{file,hash,sig_ok}] }
# ORTHO_REPO_PATH env var points to the ORTHO32 clone.

if [ -z "${ORTHO_REPO_PATH:-}" ] || [ ! -d "$ORTHO_REPO_PATH" ]; then
  echo '{"error":"ORTHO_REPO_PATH not set or directory not found","chain_ok":false,"entries":[]}'
  exit 0
fi

SEAL_PY="$ORTHO_REPO_PATH/seal/seal.py"
if [ ! -f "$SEAL_PY" ]; then
  # Try alternative locations
  if [ -f "$ORTHO_REPO_PATH/seal.py" ]; then SEAL_PY="$ORTHO_REPO_PATH/seal.py"
  elif [ -f "$ORTHO_REPO_PATH/scripts/seal.py" ]; then SEAL_PY="$ORTHO_REPO_PATH/scripts/seal.py"
  else
    echo '{"error":"seal/seal.py not found","chain_ok":false,"entries":[]}'
    exit 0
  fi
fi

OUTPUT=""
STATUS=0
OUTPUT=$(python3 "$SEAL_PY" verify 2>&1) || STATUS=$?

python3 - "$OUTPUT" "$STATUS" "$ORTHO_REPO_PATH" << 'PY'
import sys, json, re, os
output = sys.argv[1] if len(sys.argv) > 1 else ""
status = sys.argv[2] if len(sys.argv) > 2 else "0"
repo = sys.argv[3] if len(sys.argv) > 3 else ""

# Try to parse JSON output from seal.py directly
try:
    parsed = json.loads(output)
    # Normalize to canonical shape
    if isinstance(parsed, dict) and "entries" in parsed:
        # Ensure fields
        entries = []
        for e in parsed.get("entries", []):
            entries.append({"file": e.get("file",""), "hash": e.get("hash",""), "sig_ok": bool(e.get("sig_ok", e.get("sigOk", False)))})
        result = {"chain_ok": bool(parsed.get("chain_ok", parsed.get("chainOk", status=="0"))), "entries": entries}
        if "error" in parsed:
            result["error"] = parsed["error"]
        print(json.dumps(result))
        sys.exit(0)
except:
    pass

# Fallback: parse MANIFEST.seal.jsonl and CHAIN if seal.py prints text
chain_ok = (status == "0" and "error" not in output.lower() and "fail" not in output.lower())
entries = []
manifest = os.path.join(repo, "MANIFEST.seal.jsonl")
if os.path.exists(manifest):
    try:
        with open(manifest) as f:
            for line in f:
                line=line.strip()
                if not line: continue
                try:
                    j=json.loads(line)
                    entries.append({"file": j.get("file",""), "hash": j.get("hash",""), "sig_ok": bool(j.get("sig_ok", j.get("sigOk", False)))})
                except: continue
    except: pass

result = {"chain_ok": chain_ok, "entries": entries}
if status != "0":
    result["error"] = output[:2000]
print(json.dumps(result))
PY
