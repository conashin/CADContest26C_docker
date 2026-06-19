#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Entrypoint for the FloorSet local test environment.
#
# Supports the two submission paths described in the official Submission
# Guidelines:
#
#   EVAL_MODE=binary   (default)  -> executable submission
#       Stages a built binary (my_optimizer + its dependency folder, e.g.
#       _includes / _internal) next to op_wrapper.py and evaluates through the
#       wrapper:   python iccad2026_evaluate.py --evaluate op_wrapper.py
#
#   EVAL_MODE=fallback            -> source-code submission ("fallback")
#       The guidelines allow submitting source code instead of an executable.
#       In this mode the participant's Python source (a module exposing a
#       MyOptimizer / FloorplanOptimizer subclass with solve()) is staged and
#       evaluated directly:   python iccad2026_evaluate.py --evaluate <module>.py
#       Any submission requirements.txt is pip-installed first, mirroring how the
#       organizers prepare a source submission.
#
# Behaviour (both modes):
#   docker run ... <image>                 -> full evaluation (100 cases)
#   docker run ... <image> --test-id 0     -> forwarded to the evaluator
#   docker run ... <image> bash            -> interactive shell
#
# Mount your submission read-only at /submission:
#   -v "$PWD/submission:/submission:ro"
# Overrides:
#   MY_OPT_BIN     (binary mode)   path to the executable op_wrapper.py probes
#   MY_OPT_MODULE  (fallback mode) path to the source module to evaluate
# -----------------------------------------------------------------------------
set -euo pipefail

CONTEST_DIR="/opt/FloorSet/iccad2026contest"
SUBMISSION_DIR="${SUBMISSION_DIR:-/submission}"
EVAL_MODE="${EVAL_MODE:-binary}"

# Stage the submission (binary + dependency folders, or source code) into the
# contest dir so relative paths resolve.
if [ -d "$SUBMISSION_DIR" ] && [ -n "$(ls -A "$SUBMISSION_DIR" 2>/dev/null || true)" ]; then
  echo "[entrypoint] Staging submission: $SUBMISSION_DIR -> $CONTEST_DIR"
  cp -a "$SUBMISSION_DIR/." "$CONTEST_DIR/"
fi

cd "$CONTEST_DIR"

# In fallback (source-code) mode, install the submission's declared dependencies,
# mirroring how the organizers prepare a source submission before evaluation.
if [ "$EVAL_MODE" = "fallback" ] && [ -f "$CONTEST_DIR/requirements.txt" ]; then
  echo "[entrypoint] fallback mode: installing submission requirements.txt"
  pip install -r "$CONTEST_DIR/requirements.txt"
fi

# Resolve which module the evaluator should --evaluate.
resolve_eval_target() {
  if [ "$EVAL_MODE" = "fallback" ]; then
    # Source-code submission: evaluate the participant's module directly.
    if [ -n "${MY_OPT_MODULE:-}" ] && [ -f "$CONTEST_DIR/$MY_OPT_MODULE" ]; then
      echo "$MY_OPT_MODULE"; return
    fi
    for m in my_optimizer.py optimizer.py optimizer_main.py; do
      if [ -f "$CONTEST_DIR/$m" ]; then echo "$m"; return; fi
    done
    echo "[entrypoint] fallback mode: no source module found in $SUBMISSION_DIR" >&2
    echo "[entrypoint] expected one of: my_optimizer.py / optimizer.py (a module" >&2
    echo "[entrypoint] exposing a FloorplanOptimizer subclass), or set MY_OPT_MODULE." >&2
    exit 1
  else
    # Executable submission: evaluate through the official wrapper.
    echo "op_wrapper.py"
  fi
}

# Ensure the known executable layouts are runnable (binary mode only).
if [ "$EVAL_MODE" != "fallback" ]; then
  for f in "$CONTEST_DIR/my_optimizer" \
           "$CONTEST_DIR/dist/my_optimizer/my_optimizer" \
           "$CONTEST_DIR/bin/my_optimizer"; do
    if [ -f "$f" ]; then chmod +x "$f" 2>/dev/null || true; fi
  done
fi

EVAL_TARGET="$(resolve_eval_target)"
echo "[entrypoint] EVAL_MODE=$EVAL_MODE -> --evaluate $EVAL_TARGET"

# No args -> run the exact official evaluation command.
if [ "$#" -eq 0 ]; then
  exec python iccad2026_evaluate.py --evaluate "$EVAL_TARGET"
fi

# Args beginning with '-' are evaluator flags; anything else is a raw command.
case "${1}" in
  -*) exec python iccad2026_evaluate.py --evaluate "$EVAL_TARGET" "$@" ;;
  *)  exec "$@" ;;
esac
