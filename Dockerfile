# =============================================================================
# ICCAD 2026 CAD Contest - Problem C (The FloorSet Challenge)
# Local evaluation environment that mirrors the official judging machine.
#
# Official system spec (from "C_Submission_Guidelines"):
#   OS    : Debian GNU/Linux 13 (trixie)   -> base image below
#   Python: 3.13.x                          -> Debian 13 default interpreter
#   GCC/G++: 14.x                           -> Debian 13 default toolchain
#   GLIBC : 2.41                            -> Debian 13 (critical for PyInstaller)
#
# The official judge runs on an A100 + CUDA. This image is built in two variants
# selected via the TORCH_INDEX_URL build-arg:
#   cpu  -> https://download.pytorch.org/whl/cpu     (small, runs anywhere)
#   gpu  -> https://download.pytorch.org/whl/cu124   (CUDA wheels, run --gpus all)
# Either way GLIBC / Python / toolchain - the things that actually decide whether
# your PyInstaller binary loads on the judge - are matched exactly.
# =============================================================================
FROM debian:trixie-slim

LABEL org.opencontainers.image.title="ICCAD 2026 Problem C - FloorSet local test env" \
      org.opencontainers.image.description="Debian 13 / Python 3.13 / GLIBC 2.41 environment to build & evaluate my_optimizer submissions for the FloorSet Challenge." \
      org.opencontainers.image.source="https://github.com/conashin/cadcontest26c_docker"

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    VIRTUAL_ENV=/opt/venv \
    PATH=/opt/venv/bin:$PATH

# --- System packages: Python 3.13, GCC/G++ 14 toolchain, build helpers --------
# build-essential -> gcc-14/g++-14 on trixie (matches judge GCC/G++ 14.2.0)
# patchelf/binutils -> useful when post-processing PyInstaller binaries
# libgomp1 -> OpenMP runtime needed by torch/numpy at runtime
RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        git \
        build-essential \
        patchelf \
        binutils \
        python3 \
        python3-dev \
        python3-venv \
        libgomp1 \
    && rm -rf /var/lib/apt/lists/*

# --- Python virtual environment (Debian's interpreter is PEP-668 managed) ------
RUN python3 -m venv "$VIRTUAL_ENV" \
    && pip install --upgrade pip setuptools wheel

# --- PyTorch + contest dependencies + PyInstaller -----------------------------
# torch is pulled from a PyTorch wheel index chosen by TORCH_INDEX_URL:
#   cpu variant -> .../whl/cpu     (default; small, no NVIDIA driver required)
#   gpu variant -> .../whl/cu124   (CUDA-enabled; run the container with --gpus all)
# Either wheel satisfies the contest requirements.txt constraint torch>=2.0.0.
ARG TORCH_INDEX_URL=https://download.pytorch.org/whl/cpu
RUN pip install --index-url "${TORCH_INDEX_URL}" torch

# Contest's own requirements (numpy/shapely/matplotlib/tqdm/requests + torch).
# torch is already satisfied above, so it won't be re-pulled from PyPI.
COPY requirements.txt /tmp/requirements.txt
RUN pip install -r /tmp/requirements.txt

# PyInstaller so participants can build my_optimizer *inside* this image,
# guaranteeing GLIBC/Python compatibility with the judge.
RUN pip install pyinstaller

# --- Fetch the official contest harness ---------------------------------------
# Defaults to main so the local harness matches what the organizers run.
# Pin to a specific commit/tag with: --build-arg FLOORSET_REF=<sha>
ARG FLOORSET_REPO=https://github.com/IntelLabs/FloorSet.git
ARG FLOORSET_REF=main
RUN git clone "${FLOORSET_REPO}" /opt/FloorSet \
    && git -C /opt/FloorSet checkout "${FLOORSET_REF}" \
    && rm -rf /opt/FloorSet/.git

# Ship the official executable wrapper inside the contest folder so the exact
# judging command works out of the box:
#   python iccad2026_evaluate.py --evaluate op_wrapper.py
COPY op_wrapper.py /opt/FloorSet/iccad2026contest/op_wrapper.py

# --- (Optional) Pre-bake the 100-case validation dataset ----------------------
# The harness auto-downloads LiteTensorDataTest from HuggingFace on first run.
# Baking it in makes the image fully self-contained / offline-capable. If the
# build environment has no internet this step is skipped and the dataset is
# fetched at runtime instead (non-interactive, <1GB, no prompt).
ARG BAKE_DATASET=1
RUN if [ "$BAKE_DATASET" = "1" ]; then \
        cd /opt/FloorSet && \
        python -c "import sys; sys.path.insert(0, '.'); from lite_dataset_test import download_dataset; download_dataset('.')" \
        && echo '[ok] validation dataset baked into image' \
        || echo '[warn] dataset prefetch skipped (no internet at build) - will auto-download at runtime'; \
    fi

# --- Evaluation mode ----------------------------------------------------------
# Selects how the entrypoint evaluates a submission (see scripts/entrypoint.sh):
#   binary   -> executable submission, evaluated via op_wrapper.py (default)
#   fallback -> source-code submission, evaluated directly with the participant's
#               Python module (the guidelines' "you may also submit your source
#               code" fallback path). Used by the :fallback-cpu / :fallback-gpu
#               image tags.
ARG EVAL_MODE=binary
ENV EVAL_MODE=${EVAL_MODE}

COPY scripts/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

WORKDIR /opt/FloorSet/iccad2026contest

# Default: run the exact official evaluation command. Override args to scope the
# run (e.g. `--test-id 0`) or pass a full command (e.g. `bash`).
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD []
