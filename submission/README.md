# Drop your submission here

Mount this folder at `/submission` and it is staged next to the official
harness before evaluation:

```
docker run --rm -v "$PWD/submission:/submission:ro" \
  ghcr.io/<owner>/cadcontest26c_docker:latest
```

## Required layout (Beta Submission Guidelines, Section 1)

Match the flat `cadc<team_id>/` layout the organizers unpack from your
`cadc<team_id>.tar.gz` archive:

```
submission/
  op_wrapper.py       REQUIRED. Subclasses FloorplanOptimizer; passed to --evaluate.
  op_src.py           Optional but strongly recommended fallback (Section 3).
  requirements.txt    REQUIRED. May be empty (Case A) or complete (Case B) - see Section 2.
  README.md           Optional.
  <any other files>   Allowed (weights, data, helper modules) - relative paths only,
                       no absolute paths.
```

`op_wrapper.py`, `op_src.py`, and `requirements.txt` must sit directly in this
folder, not in a subdirectory - the evaluator will not find them otherwise.

You may also mount the exact archive layout, `submission/cadc<team_id>/...`;
the entrypoint auto-detects it.

## requirements.txt

- **Empty** (Case A): the environment already provides numpy, torch, scipy,
  numba, tqdm, shapely, threadpoolctl, plus the contest's own requirements.
- **Non-empty** (Case B): must be a **complete** list, including transitive
  dependencies - the evaluator installs it into a fresh, empty virtual
  environment (`python3 -m venv .venv_eval`) with nothing else pre-installed.
  A partial requirements.txt was the top cause of Alpha failures.

## Before packaging, validate locally

```bash
python3 scripts/validate_submission.py submission/
# or, against a built archive:
bash scripts/make_submission_archive.sh <team_id> submission/ out/
```

This checks the checklist items that don't require actually running the
evaluator (naming, flat layout, no absolute paths, no stray files). Still run
a full evaluation with Docker before submitting.

The contents of this folder (except this README) are git-ignored.
