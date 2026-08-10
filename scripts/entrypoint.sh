#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Entrypoint for the FloorSet local test environment, aligned with the
# ICCAD 2026 Problem C Beta Submission Guidelines.
#
# Mount your submission read-only at /submission. Either layout works:
#   submission/op_wrapper.py, requirements.txt, ...           (flat)
#   submission/cadc<team_id>/op_wrapper.py, requirements.txt  (matches the
#                                                               official archive)
#
# Guideline alignment implemented here:
#   Section 1  op_wrapper.py (REQUIRED) / op_src.py (optional) /
#              requirements.txt (REQUIRED, may be empty) must sit directly
#              inside the package. A missing or nested file fails fast with
#              the guideline section that was violated, instead of silently
#              being skipped.
#   Section 2  requirements.txt Case A (empty -> base environment) vs Case B
#              (non-empty -> fresh `.venv_eval`, installed from ONLY this
#              file) - exactly the commands the guideline says the official
#              evaluation environment runs.
#   Section 3  The evaluator tries op_wrapper.py first; if that run fails, it
#              falls back to op_src.py when present.
#   Section 5  The command actually run is:
#                python iccad2026_evaluate.py --evaluate op_wrapper.py
#
# Behaviour:
#   docker run ... <image>              -> full evaluation (100 cases)
#   docker run ... <image> --test-id 0  -> forwarded to the evaluator
#   docker run ... <image> bash         -> interactive shell
#
# Overrides:
#   SUBMISSION_DIR  where the submission is mounted (default /submission)
# -----------------------------------------------------------------------------
set -euo pipefail

CONTEST_DIR="/opt/FloorSet/iccad2026contest"
SUBMISSION_DIR="${SUBMISSION_DIR:-/submission}"

# --- Locate the package root: flat submission/, or submission/cadc<team_id>/ --
STAGE_SRC="$SUBMISSION_DIR"
if [ -d "$SUBMISSION_DIR" ] && [ ! -f "$SUBMISSION_DIR/op_wrapper.py" ]; then
  shopt -s nullglob
  team_dirs=("$SUBMISSION_DIR"/cadc*/)
  shopt -u nullglob
  if [ "${#team_dirs[@]}" -eq 1 ] && [ -f "${team_dirs[0]}op_wrapper.py" ]; then
    STAGE_SRC="${team_dirs[0]}"
    echo "[entrypoint] Detected packaged layout: staging from ${STAGE_SRC}"
  fi
fi

if [ -d "$STAGE_SRC" ] && [ -n "$(ls -A "$STAGE_SRC" 2>/dev/null || true)" ]; then
  echo "[entrypoint] Staging submission: $STAGE_SRC -> $CONTEST_DIR"
  cp -a "$STAGE_SRC/." "$CONTEST_DIR/"
fi

cd "$CONTEST_DIR"

# --- Structure checks (Guideline Section 1 / 3 / 4) ----------------------------
if [ ! -f op_wrapper.py ]; then
  echo "[entrypoint] ERROR: op_wrapper.py not found directly inside the submission." >&2
  echo "[entrypoint] Guideline Section 1/4(c): it must sit at the top level, not in a subdirectory." >&2
  exit 1
fi
if [ ! -f requirements.txt ]; then
  echo "[entrypoint] ERROR: requirements.txt not found." >&2
  echo "[entrypoint] Guideline Section 1/2/4(d): it is REQUIRED, even if empty." >&2
  exit 1
fi

# Best-effort: make well-known compiled-binary layouts executable, for the
# advanced pattern where op_wrapper.py subprocess-launches a helper binary
# (see examples/advanced_binary_wrapper/). Harmless no-op otherwise.
for f in my_optimizer dist/my_optimizer/my_optimizer bin/my_optimizer; do
  [ -f "$f" ] && chmod +x "$f" 2>/dev/null || true
done

# --- requirements.txt Case A / Case B (Guideline Section 2) --------------------
if [ -s requirements.txt ]; then
  echo "[entrypoint] requirements.txt has custom dependencies (Case B): creating a fresh .venv_eval"
  python3 -m venv .venv_eval
  .venv_eval/bin/pip install --upgrade pip >/dev/null
  .venv_eval/bin/pip install -r requirements.txt
  PYEXE=".venv_eval/bin/python"
else
  echo "[entrypoint] requirements.txt is empty (Case A): using the base evaluation environment"
  PYEXE="python"
fi

run_eval() {
  local target="$1"; shift
  "$PYEXE" iccad2026_evaluate.py --evaluate "$target" "$@"
}

# No args -> full evaluation. Args starting with '-' -> forwarded evaluator
# flags (still evaluated with the op_wrapper.py/op_src.py fallback below).
# Anything else (e.g. `bash`) -> run as a raw command, bypassing evaluation.
if [ "$#" -gt 0 ]; then
  case "$1" in
    -*) : ;;
    *) exec "$@" ;;
  esac
fi

echo "[entrypoint] Evaluating: --evaluate op_wrapper.py $*"
status=0
run_eval op_wrapper.py "$@" || status=$?
if [ "$status" -eq 0 ]; then
  exit 0
fi
echo "[entrypoint] op_wrapper.py run failed (exit $status)." >&2

if [ -f op_src.py ]; then
  echo "[entrypoint] Falling back to op_src.py, per Guideline Section 3." >&2
  run_eval op_src.py "$@"
else
  echo "[entrypoint] No op_src.py present to fall back to; failing." >&2
  exit "$status"
fi
