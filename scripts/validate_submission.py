#!/usr/bin/env python3
"""
Validate a cadc<team_id> submission package against the ICCAD 2026 Problem C
Beta Submission Guidelines (Sections 1, 2, 3, 4, 6).

Usage:
    python scripts/validate_submission.py <path/to/cadc<team_id>.tar.gz>
    python scripts/validate_submission.py <path/to/cadc<team_id>/-directory>

This checks package structure and naming only, entirely offline. It does NOT
run the evaluator - use the Docker image (see README) to actually execute
`iccad2026_evaluate.py --evaluate op_wrapper.py` against the 100 validation
cases before submitting.
"""
import argparse
import re
import shutil
import sys
import tarfile
import tempfile
from pathlib import Path

TEAM_DIR_RE = re.compile(r"^cadc[A-Za-z0-9_]+$")
ARCHIVE_NAME_RE = re.compile(r"^cadc[A-Za-z0-9_]+\.tar\.gz$")
ABS_PATH_RE = re.compile(r"""(['"])(/(?:home|Users|root|opt|mnt|Volumes)/[^'"]*)\1""")
JUNK_PATTERNS = ("*.pyc", "__pycache__", "*.log", "*.ipynb_checkpoints", "*result*.json", "*.tar.gz", "*.tgz")


class Result:
    def __init__(self):
        self.errors = []
        self.warnings = []

    def error(self, msg):
        self.errors.append(msg)

    def warn(self, msg):
        self.warnings.append(msg)

    @property
    def ok(self):
        return not self.errors


def extract_if_archive(path: Path, workdir: Path, result: Result) -> Path:
    if path.is_dir():
        return path

    if not ARCHIVE_NAME_RE.match(path.name):
        result.error(
            f"Archive name '{path.name}' does not match the required pattern "
            f"cadc<team_id>.tar.gz (Section 1 / Checklist)."
        )
    if not tarfile.is_tarfile(path):
        result.error(f"'{path}' is not a valid tar.gz archive.")
        return path

    with tarfile.open(path, "r:gz") as tf:
        members = tf.getmembers()
        extract_kwargs = {"filter": "data"} if hasattr(tarfile, "data_filter") else {}
        tf.extractall(workdir, **extract_kwargs)

    top_level = {m.name.split("/")[0] for m in members if m.name not in ("", ".")}
    if len(top_level) != 1:
        result.error(f"Archive must unpack to exactly one top-level directory, found: {sorted(top_level)}")
        return workdir
    team_dir_name = next(iter(top_level))
    if not TEAM_DIR_RE.match(team_dir_name):
        result.error(f"Top-level directory '{team_dir_name}' does not match cadc<team_id>/ (Section 1).")
    return workdir / team_dir_name


def check_required_files(root: Path, result: Result):
    op_wrapper = root / "op_wrapper.py"
    op_src = root / "op_src.py"
    requirements = root / "requirements.txt"

    if not op_wrapper.is_file():
        result.error(
            "op_wrapper.py is missing at the top level (REQUIRED, Section 1/3). "
            "If it exists in a subdirectory, the evaluator will not find it there (Section 4c)."
        )
    if not requirements.exists():
        result.error("requirements.txt is missing (REQUIRED, may be empty - Section 1/2/4d).")
    elif not requirements.is_file():
        result.error("requirements.txt exists but is not a regular file.")
    elif requirements.stat().st_size == 0:
        result.warn("requirements.txt is empty -> Case A (base environment packages only, Section 2).")
    else:
        result.warn(
            "requirements.txt is non-empty -> Case B: it MUST be COMPLETE (every package plus "
            "transitive dependencies) since the evaluator installs it into a fresh, empty venv "
            "(Section 2). A partial requirements.txt was the top Alpha failure cause (Section 4a)."
        )
    if op_src.exists() and not op_src.is_file():
        result.error("op_src.py exists but is not a regular file.")


def check_naming_and_cleanliness(root: Path, result: Result):
    py_files = sorted(p.name for p in root.glob("*.py"))
    extra_py = [f for f in py_files if f not in ("op_wrapper.py", "op_src.py")]
    if extra_py:
        result.warn(
            "Extra top-level .py files found: " + ", ".join(extra_py) + ". Guideline: submit exactly "
            "one op_wrapper.py and at most one op_src.py; no other optimizer .py files (Section 1)."
        )

    for pattern in JUNK_PATTERNS:
        hits = list(root.rglob(pattern))
        if hits:
            result.warn(
                f"Found {len(hits)} file(s) matching '{pattern}' - remove scratch/log/result files "
                "before packaging (Section 1 'keep the package clean')."
            )


def check_absolute_paths(root: Path, result: Result):
    for py_file in root.rglob("*.py"):
        try:
            text = py_file.read_text(errors="ignore")
        except OSError:
            continue
        for match in ABS_PATH_RE.finditer(text):
            result.error(
                f"{py_file.relative_to(root)}: possible absolute path literal {match.group(2)!r} - "
                "all paths must be relative to cadc<team_id>/ (Section 1/4b)."
            )


def check_nesting(root: Path, result: Result):
    for name in ("op_wrapper.py", "op_src.py", "requirements.txt"):
        nested = [p for p in root.rglob(name) if p.parent != root]
        if nested:
            rel = [str(p.relative_to(root)) for p in nested]
            result.error(f"{name} found in a subdirectory ({rel}); it must sit directly inside cadc<team_id>/ (Section 1 'No nesting').")


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("path", help="Path to cadc<team_id>.tar.gz or an unpacked cadc<team_id>/ directory")
    args = parser.parse_args()

    path = Path(args.path).resolve()
    if not path.exists():
        print(f"error: '{path}' does not exist", file=sys.stderr)
        return 2

    result = Result()
    tmpdir = None
    try:
        if path.is_dir():
            root = path
        else:
            tmpdir = Path(tempfile.mkdtemp(prefix="cadc-validate-"))
            root = extract_if_archive(path, tmpdir, result)

        if root.is_dir():
            check_required_files(root, result)
            check_naming_and_cleanliness(root, result)
            check_absolute_paths(root, result)
            check_nesting(root, result)
    finally:
        if tmpdir is not None:
            shutil.rmtree(tmpdir, ignore_errors=True)

    for w in result.warnings:
        print(f"[warn]  {w}")
    for e in result.errors:
        print(f"[error] {e}")

    if result.ok:
        print("\nPASS - package structure matches the Beta Submission Guidelines checklist.")
        print("Reminder: this only checks structure/naming. Still run the evaluator locally, e.g.:")
        print("  docker run --rm -v \"$PWD/submission:/submission:ro\" ghcr.io/<owner>/cadcontest26c_docker:cpu")
        return 0
    print(f"\nFAIL - {len(result.errors)} error(s) found. Fix these before submitting.")
    return 1


if __name__ == "__main__":
    sys.exit(main())
