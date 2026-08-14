#!/usr/bin/env bash
set -uo pipefail

# verify-hol.sh — runs HOL Light make, returns { theorems:[{id,status}] }
# ORTHO_REPO_PATH env var points to the ORTHO32 clone.

if [ -z "${ORTHO_REPO_PATH:-}" ] || [ ! -d "$ORTHO_REPO_PATH" ]; then
  echo '{"error":"ORTHO_REPO_PATH not set or directory not found","theorems":[]}'
  exit 0
fi

OUTPUT=""
STATUS=0
# HOL Light typically uses `make` in hol_light dir
if [ -f "$ORTHO_REPO_PATH/hol_light/make.sh" ] || [ -f "$ORTHO_REPO_PATH/Makefile" ] || [ -f "$ORTHO_REPO_PATH/HOLLight/Makefile" ]; then
  OUTPUT=$(cd "$ORTHO_REPO_PATH" && make -k 2>&1 || true)
  STATUS=$?
  # try hol-specific make if top-level make didn't run hol
  if [ -d "$ORTHO_REPO_PATH/hol_light" ]; then
    HOL_OUT=$(cd "$ORTHO_REPO_PATH/hol_light" && make 2>&1 || true)
    OUTPUT="$OUTPUT
$HOL_OUT"
  fi
else
  # No makefile — try ocaml hol session
  if command -v ocaml >/dev/null 2>&1; then
    OUTPUT=$(cd "$ORTHO_REPO_PATH" && ocaml 2>&1 <<'OCAML' || true
#require "hol_light";;
OCAML
)
  else
    echo '{"error":"HOL Light make not found and ocaml not on PATH","theorems":[]}'
    exit 0
  fi
fi

python3 - "$OUTPUT" "$STATUS" << 'PY'
import sys, json, re
output = sys.argv[1] if len(sys.argv) > 1 else ""
status = sys.argv[2] if len(sys.argv) > 2 else "0"
theorems = []
# Extract ml files
file_re = re.compile(r'([A-Za-z0-9_\/]+\.ml)')
files = list(dict.fromkeys(file_re.findall(output)))
# Also look for theorem names like `let ORTHO_...`
thm_re = re.compile(r'(ORTHO[-_][A-Za-z0-9_\-]+)')
names = list(dict.fromkeys(thm_re.findall(output)))
if names:
    for n in names:
        st = "verified" if status == "0" and "error" not in output.lower() and "failed" not in output.lower() else "failed"
        theorems.append({"id": n, "status": st})
elif files:
    for f in files:
        base = f.replace("/", "-").replace(".ml", "")
        st = "verified" if status == "0" and "error" not in output.lower() else "failed"
        theorems.append({"id": base, "status": st})
else:
    # No parsing — return empty with error if build failed
    pass

result = {"theorems": theorems}
if status != "0" or "error" in output.lower():
    if status != "0":
        result["error"] = output[:2000]
print(json.dumps(result))
PY
