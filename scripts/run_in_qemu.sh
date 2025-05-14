#!/usr/bin/env bash
set -euo pipefail

# -----------------------------------------------------------------------------
# run_in_qemu.sh
#
# Build (if necessary) and run the Dockerized Raspberry Pi QEMU emulator
# against your assembled image.
# -----------------------------------------------------------------------------

# 1) Build the emulator container if it doesn't exist
IMAGE_NAME="pi-qemu-emulator"
if ! docker image inspect "$IMAGE_NAME" >/dev/null 2>&1; then
  echo "[run_in_qemu] Building Docker image '$IMAGE_NAME'..."
  docker buildx build \
    --platform linux/amd64,linux/arm64 \
    --load \
    -t "$IMAGE_NAME" \
    -f Dockerfile \
    .
fi

# 2️) Determine which IMG to use
IMG="${1:-out/img/raspios-custom.img}"
if [ ! -f "$IMG" ]; then
  echo "[run_in_qemu] ERROR: Image file '$IMG' not found." >&2
  exit 1
fi
echo "[run_in_qemu] Using image: $IMG"

# 3️) Run the container
echo "[run_in_qemu] Launching Docker container..."
docker run --rm -it \
  --privileged \
  -p 2222:2222 \
  -v "$(realpath "$IMG")":/data/raspios.img:ro \
  "$IMAGE_NAME" \
  /data/raspios.img

# Notes:
#  - SSH will be forwarded to localhost:2222 (if run-qemu.sh sets up usernet with hostfwd).
#  - Adjust -p flags if you need other port mappings.
# -----------------------------------------------------------------------------
