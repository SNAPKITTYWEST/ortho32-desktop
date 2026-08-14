#!/usr/bin/env bash
set -uo pipefail

# attest.sh — reads latest attestation from bridge, returns { device, sequence, cycles, proof_id }

# Bridge attestation location — check env and common paths
BRIDGE_JSON=""

# 1. ORTHO_BRIDGE_ATTESTATION_PATH env var
if [ -n "${ORTHO_BRIDGE_ATTESTATION_PATH:-}" ] && [ -f "$ORTHO_BRIDGE_ATTESTATION_PATH" ]; then
  BRIDGE_JSON=$(cat "$ORTHO_BRIDGE_ATTESTATION_PATH" 2>&1 || true)
fi

# 2. ORTHO_REPO_PATH/attestation.json
if [ -z "$BRIDGE_JSON" ] && [ -n "${ORTHO_REPO_PATH:-}" ] && [ -f "$ORTHO_REPO_PATH/attestation.json" ]; then
  BRIDGE_JSON=$(cat "$ORTHO_REPO_PATH/attestation.json" 2>&1 || true)
fi

# 3. /tmp/ortho_attestation.json (simulated transport default)
if [ -z "$BRIDGE_JSON" ] && [ -f "/tmp/ortho_attestation.json" ]; then
  BRIDGE_JSON=$(cat "/tmp/ortho_attestation.json" 2>&1 || true)
fi

# 4. Try transport simulated file
if [ -z "$BRIDGE_JSON" ] && [ -n "${ORTHO_REPO_PATH:-}" ] && [ -f "$ORTHO_REPO_PATH/build/attestation.json" ]; then
  BRIDGE_JSON=$(cat "$ORTHO_REPO_PATH/build/attestation.json" 2>&1 || true)
fi

if [ -z "$BRIDGE_JSON" ]; then
  echo '{"error":"no attestation found from bridge","device":"","sequence":0,"cycles":0,"proof_id":""}'
  exit 0
fi

python3 - "$BRIDGE_JSON" << 'PY'
import sys, json
raw = sys.argv[1] if len(sys.argv)>1 else ""
try:
    j=json.loads(raw)
    # Normalize snake/camel
    device = j.get("device", j.get("deviceId",""))
    sequence = j.get("sequence", j.get("seq",0))
    cycles = j.get("cycles", j.get("cycleCount",0))
    proof_id = j.get("proof_id", j.get("proofId", j.get("proofID","")))
    # If j is array, take latest
    if isinstance(j, list) and len(j)>0:
        j=j[-1]
        device = j.get("device","")
        sequence = j.get("sequence",0)
        cycles = j.get("cycles",0)
        proof_id = j.get("proof_id", j.get("proofId",""))
    print(json.dumps({"device": device, "sequence": int(sequence), "cycles": int(cycles), "proof_id": proof_id}))
except Exception as e:
    print(json.dumps({"error": f"attestation parse failed: {e}", "device":"", "sequence":0, "cycles":0, "proof_id":""}))
PY
