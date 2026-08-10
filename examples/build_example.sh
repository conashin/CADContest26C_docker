#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Demonstrates the ADVANCED pattern (see examples/advanced_binary_wrapper/):
# an op_wrapper.py that subprocess-launches a compiled binary, instead of the
# default pure-Python template shipped at the repo root. Run this INSIDE the
# container so the resulting binary is GLIBC/Python-compatible with the judge.
#
#   docker run --rm -v "$PWD:/work" -w /work \
#     ghcr.io/<owner>/cadcontest26c_docker:latest \
#     bash examples/build_example.sh
#
# Produces ./submission/my_optimizer and ./submission/op_wrapper.py, ready for:
#   docker run --rm -v "$PWD/submission:/submission:ro" ghcr.io/<owner>/cadcontest26c_docker:latest
#
# Guideline reminder: also ship an op_src.py with a pure-Python fallback (see
# root op_src.py) - the evaluator tries op_wrapper.py first, then op_src.py.
# -----------------------------------------------------------------------------
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
SRC="$HERE/advanced_binary_wrapper"
OUT="$HERE/../submission"

cd "$SRC"
rm -rf build dist
# --onefile -> single self-contained binary named "my_optimizer".
# For the --onedir layout (binary + dependency folder) use --onedir instead;
# op_wrapper.py also probes dist/my_optimizer/my_optimizer.
pyinstaller --onefile --clean --name my_optimizer optimizer_main.py

mkdir -p "$OUT"
cp -f dist/my_optimizer "$OUT/my_optimizer"
chmod +x "$OUT/my_optimizer"
cp -f "$SRC/op_wrapper.py" "$OUT/op_wrapper.py"
touch "$OUT/requirements.txt"
echo "[ok] Wrote $OUT/my_optimizer, $OUT/op_wrapper.py, $OUT/requirements.txt"
