#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Build the demo optimizer into a PyInstaller binary, the same way you would
# package your real submission. Run this INSIDE the container so the resulting
# binary is GLIBC/Python-compatible with the judge.
#
#   docker run --rm -v "$PWD:/work" -w /work \
#     ghcr.io/<owner>/cadcontest26c_docker:latest \
#     bash examples/build_example.sh
#
# Produces ./submission/my_optimizer , ready for:
#   docker run --rm -v "$PWD/submission:/submission:ro" ghcr.io/<owner>/cadcontest26c_docker:latest
# -----------------------------------------------------------------------------
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
SRC="$HERE/my_optimizer_src"
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
echo "[ok] Wrote $OUT/my_optimizer"
