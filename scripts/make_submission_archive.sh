#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Package a local submission directory into cadc<team_id>.tar.gz per the Beta
# Submission Guidelines (Section 1), then validate it with validate_submission.py.
#
# Usage:
#   scripts/make_submission_archive.sh <team_id> <source_dir> [output_dir]
#
# <source_dir> must directly contain op_wrapper.py and requirements.txt (plus
# optional op_src.py, README.md, helper files) - laid out exactly as it should
# appear inside cadc<team_id>/.
# -----------------------------------------------------------------------------
set -euo pipefail

if [ "$#" -lt 2 ]; then
  echo "usage: $0 <team_id> <source_dir> [output_dir]" >&2
  exit 1
fi

TEAM_ID="$1"
SRC_DIR="$2"
OUT_DIR="${3:-.}"
HERE="$(cd "$(dirname "$0")" && pwd)"

if [ ! -d "$SRC_DIR" ]; then
  echo "error: source dir '$SRC_DIR' not found" >&2
  exit 1
fi

TEAM_DIR_NAME="cadc${TEAM_ID}"
ARCHIVE_NAME="${TEAM_DIR_NAME}.tar.gz"
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

mkdir -p "$STAGE/$TEAM_DIR_NAME"
cp -a "$SRC_DIR/." "$STAGE/$TEAM_DIR_NAME/"

mkdir -p "$OUT_DIR"
tar -czf "$OUT_DIR/$ARCHIVE_NAME" -C "$STAGE" "$TEAM_DIR_NAME"
echo "[ok] wrote $OUT_DIR/$ARCHIVE_NAME"

echo "[..] validating against the Beta Submission Guidelines checklist"
python3 "$HERE/validate_submission.py" "$OUT_DIR/$ARCHIVE_NAME"
