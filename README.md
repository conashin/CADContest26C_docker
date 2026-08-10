# ICCAD 2026 CAD Contest — Problem C (FloorSet) Local Test Environment

[![build-and-push](https://github.com/conashin/CADContest26C_docker/actions/workflows/build-and-push.yml/badge.svg)](https://github.com/conashin/CADContest26C_docker/actions/workflows/build-and-push.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](./LICENSE)

A reproducible Docker environment that mirrors the **official judging machine** of
the [ICCAD 2026 CAD Contest](https://www.iccad-contest.org/) — **Problem C: The
FloorSet Challenge** — aligned with the **Beta Submission Guidelines**, together
with a GitHub Actions pipeline that builds the image and publishes it to the
**GitHub Container Registry (GHCR)**.

It lets you `docker pull` the image to any machine and exercise your submission
with the exact judging command before you submit:

```bash
python iccad2026_evaluate.py --evaluate op_wrapper.py
```

---

## ⚠️ Disclaimer

> **This image is NOT an officially certified evaluation environment.**
> It is an unofficial, community-built environment intended only for quick,
> convenient sanity checking **before** submission. Any results, scores, or
> runtime numbers produced here are **for reference only** and may differ from
> the official evaluation. Always defer to the contest organizers' official
> environment, rules, and results.
>
> **本 repo 產生的 Docker image 並非官方認證的評測環境**，僅供提交前的簡易測試之用，
> 所有結果僅供參考，請以大會官方環境與結果為準。

This repository is not affiliated with, endorsed by, or sponsored by Intel, the
FloorSet authors, or the ICCAD CAD Contest organizers.

---

## Table of Contents

- [Overview](#overview)
- [Environment Specification](#environment-specification)
- [Submission Package (Beta Guidelines)](#submission-package-beta-guidelines)
- [requirements.txt — Case A / Case B](#requirementstxt--case-a--case-b)
- [Image Variants](#image-variants)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Usage](#usage)
- [Packaging & Validating Your Submission](#packaging--validating-your-submission)
- [Pre-submission Checklist](#pre-submission-checklist)
- [Advanced: Wrapping a Compiled Binary](#advanced-wrapping-a-compiled-binary)
- [References](#references)
- [License](#license)

---

## Overview

The official judge runs your `cadc<team_id>/` package directly through the
contest's evaluation harness:

```
python iccad2026_evaluate.py --evaluate op_wrapper.py
```

`op_wrapper.py` must be a plain Python file that subclasses `FloorplanOptimizer`
and implements `solve()` — no compiled binary or subprocess protocol is
required. This image bundles:

- The official [`IntelLabs/FloorSet`](https://github.com/IntelLabs/FloorSet)
  `iccad2026contest/` evaluation harness (tracks `main` by default).
- Reference `op_wrapper.py` / `op_src.py` templates, placed next to the harness
  so the image runs end-to-end out of the box.
- An entrypoint that validates your package structure, handles
  `requirements.txt` Case A/B, and reproduces the guidelines' `op_wrapper.py`
  → `op_src.py` fallback behavior locally.
- The 100-case validation dataset (`LiteTensorDataTest`), pre-baked when network
  access is available at build time so evaluation can run offline.

---

## Environment Specification

Source: the *ICCAD 2026 FloorSet Challenge — Beta Submission Guidelines*.

Each Beta submission is evaluated individually on a **dedicated machine with 48
CPU cores and an NVIDIA A100 80GB GPU**, with all resources available
exclusively to that submission.

| Item        | Official judge                                         | This image                                        |
| ----------- | ------------------------------------------------------ | ------------------------------------------------- |
| OS          | Debian GNU/Linux 13                                    | `debian:trixie-slim` (Debian 13) ✅                |
| Python      | 3.13.x                                                 | Debian 13 system Python 3.13 ✅                    |
| GCC / G++   | 14.2.0                                                 | `build-essential` (GCC/G++ 14) ✅                  |
| GLIBC (ldd) | 2.41                                                   | Debian 13 → 2.41 ✅                                |
| CPU / GPU   | 48 cores, NVIDIA A100 80GB (dedicated)                 | Your machine's cores; `:gpu` variant + any CUDA GPU |
| Preinstalled Python deps (Case A) | numpy, torch, scipy, numba, tqdm, shapely, threadpoolctl, + contest `requirements.txt` | Installed from this repo's `requirements.txt` ✅ |

> The official machine uses an NVIDIA A100 with CUDA and 48 dedicated CPU
> cores. Absolute runtime numbers will differ from your local machine; use
> this image to validate **correctness and packaging**, not to benchmark
> final runtime/score.

---

## Submission Package (Beta Guidelines)

Each team submits exactly one `cadc<team_id>.tar.gz`, which must unpack to a
**flat** directory named `cadc<team_id>/`:

```
cadc<team_id>/
    op_wrapper.py          REQUIRED. Subclasses FloorplanOptimizer; the file
                            passed to --evaluate.
    op_src.py               Optional but strongly recommended. Full,
                            self-contained source used if op_wrapper.py fails
                            or cannot run standalone.
    requirements.txt        REQUIRED (may be empty). See below.
    README.md                Optional. Only if you need special instructions.
    <any other files>        Allowed (model weights, data, helper modules).
                            Reference them with paths relative to
                            cadc<team_id>/ — never absolute paths.
```

**No nesting:** `op_wrapper.py`, `op_src.py`, and `requirements.txt` must sit
**directly inside** `cadc<team_id>/`, not in a subdirectory — the evaluator
will not find them otherwise.

**Keep the package clean:** no unrelated files (personal scripts, test
outputs, result JSONs, checkpoints from other approaches, notebooks, logs);
exactly one `op_wrapper.py` and at most one `op_src.py`; remove unused large
binaries. Violations of naming or cleanliness can lead to disqualification.

The evaluator tries `op_wrapper.py` first; if that run fails, it falls back to
`op_src.py`. This image's entrypoint reproduces that behavior locally (see
[scripts/entrypoint.sh](scripts/entrypoint.sh)).

---

## requirements.txt — Case A / Case B

- **Case A — no custom dependencies:** leave `requirements.txt` **empty**
  (zero bytes). The evaluation environment already provides `numpy`, `torch`,
  `scipy`, `numba`, `tqdm`, `shapely`, `threadpoolctl`, and everything in the
  contest's own `requirements.txt`.
- **Case B — custom dependencies:** provide a **complete** `requirements.txt`
  listing every package your optimizer needs, including transitive
  dependencies. The evaluation environment creates a fresh virtual
  environment using **only** this file:

  ```bash
  python3 -m venv .venv_eval
  .venv_eval/bin/pip install -r requirements.txt
  ```

  A partial `requirements.txt` (only the packages you added, omitting
  standard ones) was the most common cause of Alpha failures — the fresh venv
  does **not** inherit numpy/torch/etc. from the base environment once you go
  down the Case B path.

This image's entrypoint performs exactly this Case A/B branching against your
mounted submission, so a partial `requirements.txt` fails locally the same
way it would on the judge.

---

## Image Variants

Two variants are published, sharing the same Debian 13 / Python 3.13 / GLIBC
2.41 base and differing only in the PyTorch wheel:

| Tag                  | PyTorch wheel | Intended use                                                 | Size    |
| -------------------- | ------------- | ------------------------------------------------------------ | ------- |
| `:cpu` (= `:latest`) | `whl/cpu`     | Any machine, no NVIDIA driver required. Verifies packaging, output validity, and full scoring. | ~1.5 GB |
| `:gpu`               | `whl/cu124`   | Machines with an NVIDIA GPU; aligns with the A100/CUDA judge and measures GPU runtime. Requires `--gpus all`. | ~6–7 GB |

Published image names:

```
ghcr.io/conashin/cadcontest26c_docker:cpu   # also tagged :latest
ghcr.io/conashin/cadcontest26c_docker:gpu   # CUDA build; run with --gpus all
```

---

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/) (and, for the `:gpu` variant,
  the [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html)).

- Docker Image: Pull the docker image directly from GHCR:

  ```bash
  docker pull ghcr.io/conashin/cadcontest26c_docker:cpu
  ```

  > If you fork this repository and keep your package private, authenticate first
  > with a Personal Access Token that has the `read:packages` scope:
  > `echo "$GHCR_PAT" | docker login ghcr.io -u <your-github-username> --password-stdin`

---

## Quick Start

```bash
# 1. Pull the CPU image (public — no login required)
docker pull ghcr.io/conashin/cadcontest26c_docker:cpu

# 2. Put your op_wrapper.py (+ requirements.txt, optional op_src.py) in
#    ./submission, then run the official evaluation
docker run --rm -v "$PWD/submission:/submission:ro" \
  ghcr.io/conashin/cadcontest26c_docker:cpu
```

---

## Usage

Place your submission files in a local `submission/` directory, matching the
[Submission Package](#submission-package-beta-guidelines) layout:

```
submission/
  op_wrapper.py        # REQUIRED — subclasses FloorplanOptimizer
  op_src.py             # optional fallback
  requirements.txt      # REQUIRED (may be empty)
```

(You may instead mount `submission/cadc<team_id>/...` — the entrypoint
auto-detects the exact archive layout.)

The container stages everything mounted at `/submission` next to the
evaluation harness, validates the required files are present at the top
level, resolves `requirements.txt` Case A/B, then evaluates.

**Full evaluation (100 validation cases):**

```bash
# CPU
docker run --rm -v "$PWD/submission:/submission:ro" \
  ghcr.io/conashin/cadcontest26c_docker:cpu

# GPU (requires NVIDIA GPU + NVIDIA Container Toolkit)
docker run --rm --gpus all -v "$PWD/submission:/submission:ro" \
  ghcr.io/conashin/cadcontest26c_docker:gpu
```

**Single test case** (arguments are forwarded to the evaluator):

```bash
docker run --rm -v "$PWD/submission:/submission:ro" \
  ghcr.io/conashin/cadcontest26c_docker:cpu --test-id 0
```

**Validate submission format / show the scoring formula:**

```bash
docker run --rm -v "$PWD/submission:/submission:ro" \
  ghcr.io/conashin/cadcontest26c_docker:cpu --validate op_wrapper.py

docker run --rm ghcr.io/conashin/cadcontest26c_docker:cpu --info
```

**Interactive shell:**

```bash
docker run --rm -it -v "$PWD/submission:/submission:ro" \
  ghcr.io/conashin/cadcontest26c_docker:cpu bash
# Inside: cd /opt/FloorSet/iccad2026contest && python iccad2026_evaluate.py --evaluate op_wrapper.py
```

---

## Packaging & Validating Your Submission

Two host-side scripts (no Docker required) help you satisfy the packaging
checklist before you build a full evaluation run:

```bash
# Check an unpacked directory or an already-built archive against the
# guidelines' structure/naming rules (Sections 1, 2, 4, 6):
python3 scripts/validate_submission.py submission/
python3 scripts/validate_submission.py cadc0042.tar.gz

# Package submission/ into cadc<team_id>.tar.gz and validate it in one step:
bash scripts/make_submission_archive.sh 0042 submission/ out/
```

The validator flags: missing/nested `op_wrapper.py` or `requirements.txt`,
extra top-level `.py` files, likely absolute-path literals in your code,
scratch/log/result-JSON clutter, and archive/directory naming that doesn't
match `cadc<team_id>`. It does **not** run the evaluator — pair it with a full
Docker run before submitting.

---

## Pre-submission Checklist

From the Beta Submission Guidelines:

- [ ] Archive named `cadc<team_id>.tar.gz`
- [ ] `cadc<team_id>/` is flat — `op_wrapper.py`, `requirements.txt` at top level
- [ ] `requirements.txt` present (empty if no custom deps, complete if custom)
- [ ] No absolute paths in code
- [ ] Tested locally: `python iccad2026_evaluate.py --evaluate op_wrapper.py`
- [ ] `op_wrapper.py` runs all 100 validation cases without crashing

`scripts/validate_submission.py` checks the structural items automatically;
run a full Docker evaluation (see [Usage](#usage)) for the last two.

---

## Advanced: Wrapping a Compiled Binary

The guidelines only require `op_wrapper.py` to be a plain `.py` file that
subclasses `FloorplanOptimizer` — what it does internally is up to you. If
your real solver is a native/PyInstaller binary, `op_wrapper.py` can
subprocess-launch it; the binary just becomes one of the "any other files"
allowed alongside it. See
[`examples/advanced_binary_wrapper/`](examples/advanced_binary_wrapper/) for
a full example, and strongly consider shipping a pure-Python `op_src.py` as a
genuine fallback in case the binary fails to load on the judge.

To guarantee the binary's GLIBC/Python match the judge, package it **inside
this container** with PyInstaller:

```bash
docker run --rm -v "$PWD:/work" -w /work \
  ghcr.io/conashin/cadcontest26c_docker:cpu \
  bash -lc "pyinstaller --onefile --name my_optimizer your_program.py && \
            mkdir -p submission && cp dist/my_optimizer submission/"
```

Or run the bundled demo end-to-end:

```bash
docker run --rm -v "$PWD:/work" -w /work \
  ghcr.io/conashin/cadcontest26c_docker:cpu \
  bash examples/build_example.sh

docker run --rm -v "$PWD/submission:/submission:ro" \
  ghcr.io/conashin/cadcontest26c_docker:cpu
```

---

## References

- **Intel FloorSet** (datasets, contest harness, and `iccad2026contest/`):
  <https://github.com/IntelLabs/FloorSet>
- **ICCAD CAD Contest** (official contest site):
  <https://www.iccad-contest.org/>

This repository merely packages the above into a reproducible local test
environment. All rights to FloorSet and the contest materials belong to their
respective owners.

---

## License

Released under the [MIT License](./LICENSE) — you are free to use, copy, modify,
and distribute this work, including for commercial purposes. The only condition
is that you retain the copyright and permission notice (i.e., credit this
repository: <https://github.com/conashin/CADContest26C_docker>).

The MIT License covers this repository's own files only. Third-party materials
that this project downloads or builds against — notably
[Intel FloorSet](https://github.com/IntelLabs/FloorSet) and the
[ICCAD CAD Contest](https://www.iccad-contest.org/) materials — remain subject
to their respective licenses and terms.
