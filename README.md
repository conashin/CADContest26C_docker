# ICCAD 2026 CAD Contest — Problem C (FloorSet) Local Test Environment

[![build-and-push](https://github.com/conashin/CADContest26C_docker/actions/workflows/build-and-push.yml/badge.svg)](https://github.com/conashin/CADContest26C_docker/actions/workflows/build-and-push.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](./LICENSE)

A reproducible Docker environment that mirrors the **official judging machine** of
the [ICCAD 2026 CAD Contest](https://www.iccad-contest.org/) — **Problem C: The
FloorSet Challenge** — together with a GitHub Actions pipeline that builds the
image and publishes it to the **GitHub Container Registry (GHCR)**.

It lets you `docker pull` the image to any machine and exercise your submission
binary with the exact judging command before you submit:

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
- [Image Variants](#image-variants)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Usage](#usage)
- [Building Binary Inside the Container](#building-binary-inside-the-container)
- [References](#references)
- [License](#license)

---

## Overview

The official judge wraps each participant's executable (`my_optimizer`) with a
small Python script (`op_wrapper.py`) and invokes it through the contest's
evaluation harness. Whether your PyInstaller binary loads correctly on the judge
is determined primarily by the **GLIBC version, Python version, and compiler
toolchain** of the build machine. This image matches those exactly, so a binary
you build and test here is expected to behave the same way on the official
environment.

The image bundles:

- The official [`IntelLabs/FloorSet`](https://github.com/IntelLabs/FloorSet)
  `iccad2026contest/` evaluation harness (tracks `main` by default).
- The executable wrapper `op_wrapper.py`, placed next to the harness.
- **PyInstaller**, so you can package your binary *inside* the container and
  guarantee GLIBC/Python compatibility with the judge. **(for reference only)**
- The 100-case validation dataset (`LiteTensorDataTest`), pre-baked when network
  access is available at build time so evaluation can run offline.

---

## Environment Specification

Source: the official *[Problem C Submission Guidelines](https://drive.google.com/file/d/1OiKhswOKrlLNStzUHt1IDN6Ej2kXXJNW/view)*

| Item        | Official judge                                         | This image                                        |
| ----------- | ------------------------------------------------------ | ------------------------------------------------- |
| OS          | Debian GNU/Linux 13                                    | `debian:trixie-slim` (Debian 13) ✅                |
| Python      | 3.13.x                                                 | Debian 13 system Python 3.13 ✅                    |
| GCC / G++   | 14.2.0                                                 | `build-essential` (GCC/G++ 14) ✅                  |
| GLIBC (ldd) | 2.41                                                   | Debian 13 → 2.41 ✅                                |
| PyTorch     | 2.12.0+cu130 (A100/CUDA)                               | CPU **or** CUDA variant (see below)               |
| Python deps | torch / numpy / shapely / matplotlib / tqdm / requests | Installed from the contest's `requirements.txt` ✅ |

> The official machine uses an NVIDIA A100 with CUDA. The GLIBC / Python /
> toolchain layers — the ones that actually decide whether your binary loads —
> are matched exactly in both image variants.

---

## Image Variants

Four variants are published. They share the same Debian 13 / Python 3.13 / GLIBC
2.41 base and differ in the PyTorch wheel and the **evaluation mode**:

- **binary** mode (`:cpu`, `:gpu`) evaluates an *executable* submission through
  `op_wrapper.py` — the official judging path for a PyInstaller binary.
- **fallback** mode (`:fallback-cpu`, `:fallback-gpu`) evaluates a *source-code*
  submission directly, mirroring the guidelines' fallback path ("As a fallback,
  you may also submit your source code.").

| Tag                  | PyTorch wheel | Eval mode | Intended use                                                 | Size    |
| -------------------- | ------------- | --------- | ------------------------------------------------------------ | ------- |
| `:cpu` (= `:latest`) | `whl/cpu`     | binary    | Any machine, no NVIDIA driver required. Verifies executable packaging, output validity, and full scoring. | ~1.5 GB |
| `:gpu`               | `whl/cu124`   | binary    | Machines with an NVIDIA GPU; aligns with the A100/CUDA judge and measures GPU runtime. Requires `--gpus all`. | ~6–7 GB |
| `:fallback-cpu`      | `whl/cpu`     | fallback  | Verifies a **source-code** submission evaluates correctly (no binary). Installs the submission's `requirements.txt`. | ~1.5 GB |
| `:fallback-gpu`      | `whl/cu124`   | fallback  | Source-code submission on an NVIDIA GPU. Requires `--gpus all`. | ~6–7 GB |

Published image names:

```
ghcr.io/conashin/cadcontest26c_docker:cpu            # also tagged :latest
ghcr.io/conashin/cadcontest26c_docker:gpu            # CUDA build; run with --gpus all
ghcr.io/conashin/cadcontest26c_docker:fallback-cpu   # source-code path
ghcr.io/conashin/cadcontest26c_docker:fallback-gpu   # source-code path; run with --gpus all
```

### Testing the source-code (fallback) path

Put your source module — a `.py` exposing a `FloorplanOptimizer` subclass with a
`solve()` method (e.g. derived from the contest's `optimizer_template.py`) —
plus any `requirements.txt`/helper files into `submission/`, then run a
`fallback-*` image. The entrypoint installs the submission's `requirements.txt`
(if present) and runs `python iccad2026_evaluate.py --evaluate <your_module>.py`
directly.

```bash
# Demo source-code submission (works out of the box)
cp examples/fallback_src/my_optimizer.py submission/

docker run --rm -v "$PWD/submission:/submission:ro" \
  ghcr.io/conashin/cadcontest26c_docker:fallback-cpu
```

The entrypoint probes `my_optimizer.py`, then `optimizer.py`, then
`optimizer_main.py`; override with `-e MY_OPT_MODULE=<relative-path>.py`.

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

# 2. Put your built artifacts in ./submission, then run the official evaluation
docker run --rm -v "$PWD/submission:/submission:ro" \
  ghcr.io/conashin/cadcontest26c_docker:cpu
```

---

## Usage

Place your submission artifacts in a local `submission/` directory:

```
submission/
  my_optimizer            # your PyInstaller executable
  _includes/              # your dependency / data folder, if any
```

The container stages everything mounted at `/submission` next to `op_wrapper.py`
before running. `op_wrapper.py` probes these paths in order:
`./my_optimizer`, `./dist/my_optimizer/my_optimizer`, `./bin/my_optimizer`.
Override with `-e MY_OPT_BIN=<relative-or-absolute-path>`.

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

## Building Binary Inside the Container

To guarantee the binary's GLIBC/Python match the judge, package it **inside this
container** with PyInstaller:

```bash
docker run --rm -v "$PWD:/work" -w /work \
  ghcr.io/conashin/cadcontest26c_docker:cpu \
  bash -lc "pyinstaller --onefile --name my_optimizer your_program.py && \
            mkdir -p submission && cp dist/my_optimizer submission/"
```

Then evaluate it using the [Usage](#usage) commands above.

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
