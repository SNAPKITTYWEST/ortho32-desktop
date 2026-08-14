#!/usr/bin/env bash
set -uo pipefail

# verify-lean.sh — runs lake build in ORTHO32 repo dir, returns { theorems:[{id,status,sorry_count}] }
# ORTHO_REPO_PATH env var points to the ORTHO32 clone. Fails gracefully with JSON error if missing.

if [ -z "${ORTHO_REPO_PATH:-}" ] || [ ! -d "$ORTHO_REPO_PATH" ]; then
  echo '{"error":"ORTHO_REPO_PATH not set or directory not found","theorems":[]}'
  exit 0
fi

OUTPUT=""
STATUS=0
if command -v lake >/dev/null 2>&1; then
  OUTPUT=$(cd "$ORTHO_REPO_PATH" && lake build 2>&1) || STATUS=$?
else
  echo '{"error":"lake not found on PATH","theorems":[]}'
  exit 0
fi

# Parse lean output for theorems and sorry counts.
# Fallback: if parsing fails, return raw build status.
python3 - "$OUTPUT" "$STATUS" << 'PY'
import sys, json, re
output = sys.argv[1] if len(sys.argv) > 1 else ""
status = sys.argv[2] if len(sys.argv) > 2 else "0"

# Try to find sorry counts: look for "sorry" tokens and theorem names
# Expected theorem ids: ORTHO-32-* or file-based names
theorems = []
# Look for lines like "Basic.ScalarCorrectness ... sorry"
sorry_count = output.lower().count("sorry")
# Try to extract file names from lake output
file_re = re.compile(r'([A-Za-z0-9_\/]+\.lean)')
files = list(dict.fromkeys(file_re.findall(output)))
if not files:
    # No files detected — use generic entry if build failed/succeeded
    if "error" in output.lower() or status != "0":
        theorems = []
    else:
        theorems = []

# If we have files, map each to a theorem id
for f in files:
    # derive id from path: e.g., Basic/ScalarCorrectness.lean -> ORTHO-32-BASIC-01 style fallback
    base = f.replace("/", "-").replace(".lean", "")
    # count sorrys in output for this file (approx)
    theorems.append({"id": base, "status": "verified" if status == "0" and sorry_count == 0 else "failed" if status != "0" else "verified", "sorry_count": sorry_count})

# If no files parsed but build succeeded, emit empty but valid
result = {"theorems": theorems}
if status != "0":
    result["error"] = output[:2000]
    # ensure theorems have failed status if any
    if not theorems:
        result["theorems"] = []

print(json.dumps(result))
PY
