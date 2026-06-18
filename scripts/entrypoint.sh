#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Entrypoint for the FloorSet local test environment.
#
# Stages a submitted binary (my_optimizer + its dependency folder, e.g.
# _includes / _internal) next to op_wrapper.py, then runs the official judging
# command. Behaviour:
#
#   docker run ... <image>                 -> full evaluation (100 cases)
#   docker run ... <image> --test-id 0     -> forwarded to the evaluator
#   docker run ... <image> bash            -> interactive shell
#
# Mount your submission read-only at /submission:
#   -v "$PWD/submission:/submission:ro"
# or override the lookup path entirely with MY_OPT_BIN.
# -----------------------------------------------------------------------------
set -euo pipefail

CONTEST_DIR="/opt/FloorSet/iccad2026contest"
SUBMISSION_DIR="${SUBMISSION_DIR:-/submission}"

# Stage the submission (binary + dependency folders) into the contest dir so the
# paths op_wrapper.py probes (./my_optimizer, ./dist/my_optimizer/my_optimizer,
# ./bin/my_optimizer) resolve.
if [ -d "$SUBMISSION_DIR" ] && [ -n "$(ls -A "$SUBMISSION_DIR" 2>/dev/null || true)" ]; then
  echo "[entrypoint] Staging submission: $SUBMISSION_DIR -> $CONTEST_DIR"
  cp -a "$SUBMISSION_DIR/." "$CONTEST_DIR/"
fi

# Ensure the known executable layouts are runnable.
for f in "$CONTEST_DIR/my_optimizer" \
         "$CONTEST_DIR/dist/my_optimizer/my_optimizer" \
         "$CONTEST_DIR/bin/my_optimizer"; do
  if [ -f "$f" ]; then chmod +x "$f" 2>/dev/null || true; fi
done

cd "$CONTEST_DIR"

# No args -> run the exact official evaluation command.
if [ "$#" -eq 0 ]; then
  exec python iccad2026_evaluate.py --evaluate op_wrapper.py
fi

# Args beginning with '-' are evaluator flags; anything else is a raw command.
case "${1}" in
  -*) exec python iccad2026_evaluate.py --evaluate op_wrapper.py "$@" ;;
  *)  exec "$@" ;;
esac
