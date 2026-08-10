# =============================================================================
# ICCAD 2026 CAD Contest - Problem C (The FloorSet Challenge)
# Local evaluation environment aligned with the Beta Submission Guidelines:
# each submission is a plain-Python cadc<team_id>/ package (op_wrapper.py
# REQUIRED, op_src.py optional, requirements.txt REQUIRED) evaluated on a
# dedicated machine with 48 CPU cores + an NVIDIA A100 80GB GPU.
#
# Official system spec (from "C_Submission_Guidelines"):
#   OS    : Debian GNU/Linux 13 (trixie)   -> base image below
#   Python: 3.13.x                          -> Debian 13 default interpreter
#   GCC/G++: 14.x                           -> Debian 13 default toolchain
#   GLIBC : 2.41                            -> Debian 13
#
# The official judge runs on an A100 + CUDA. This image is built in two
# variants selected via the TORCH_INDEX_URL build-arg:
#   cpu  -> https://download.pytorch.org/whl/cpu     (small, runs anywhere)
#   gpu  -> https://download.pytorch.org/whl/cu124   (CUDA wheels, run --gpus all)
# Either way, Python / toolchain / preinstalled packages are matched exactly,
# so op_wrapper.py behaves the same locally as on the judge.
# =============================================================================
FROM debian:trixie-slim

LABEL org.opencontainers.image.title="ICCAD 2026 Problem C - FloorSet local test env" \
      org.opencontainers.image.description="Debian 13 / Python 3.13 / GLIBC 2.41 environment to evaluate cadc<team_id> op_wrapper.py submissions for the FloorSet Challenge." \
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

# Base packages the Beta Submission Guidelines (Section 2, Case A) say are
# always available in the evaluation environment: numpy, torch, scipy, numba,
# tqdm, shapely, threadpoolctl, plus the contest's own requirements.txt.
# torch is already satisfied above, so it won't be re-pulled from PyPI.
COPY requirements.txt /tmp/requirements.txt
RUN pip install -r /tmp/requirements.txt

# PyInstaller: optional, for the ADVANCED pattern where op_wrapper.py
# subprocess-launches a compiled binary (see examples/advanced_binary_wrapper/).
# Not required by the Beta Submission Guidelines, which only ask for plain
# .py files - most submissions won't need this.
RUN pip install pyinstaller

# --- Fetch the official contest harness ---------------------------------------
# Defaults to main so the local harness matches what the organizers run.
# Pin to a specific commit/tag with: --build-arg FLOORSET_REF=<sha>
ARG FLOORSET_REPO=https://github.com/IntelLabs/FloorSet.git
ARG FLOORSET_REF=main
RUN git clone "${FLOORSET_REPO}" /opt/FloorSet \
    && git -C /opt/FloorSet checkout "${FLOORSET_REF}" \
    && rm -rf /opt/FloorSet/.git

# Ship the reference op_wrapper.py / op_src.py templates inside the contest
# folder so the exact judging command works out of the box:
#   python iccad2026_evaluate.py --evaluate op_wrapper.py
# A mounted submission (see scripts/entrypoint.sh) overwrites these with the
# participant's own cadc<team_id>/ package.
COPY op_wrapper.py op_src.py /opt/FloorSet/iccad2026contest/

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

# --- Entrypoint -----------------------------------------------------------
# Stages the mounted submission, validates cadc<team_id>/ structure, handles
# requirements.txt Case A/B, and evaluates op_wrapper.py with an automatic
# op_src.py fallback - see scripts/entrypoint.sh for the guideline mapping.
COPY scripts/entrypoint.sh /usr/local/bin/entrypoint.sh
COPY scripts/validate_submission.py /usr/local/bin/validate_submission.py
RUN chmod +x /usr/local/bin/entrypoint.sh /usr/local/bin/validate_submission.py

WORKDIR /opt/FloorSet/iccad2026contest

# Default: run the exact official evaluation command. Override args to scope the
# run (e.g. `--test-id 0`) or pass a full command (e.g. `bash`).
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD []
