# syntax=docker/dockerfile:1.4
#
# Multi-arch Dockerfile for Raspberry Pi 4 emulation
#
# Build with buildx:
#   docker buildx build --platform linux/amd64,linux/arm64 -t pi-qemu-emulator .

FROM --platform=$BUILDPLATFORM ubuntu:20.04

# Tell Docker which architecture we're building for
ARG TARGETPLATFORM
ARG TARGETARCH
ARG TARGETVARIANT

# Noninteractive installs
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
      # QEMU system emulators for 32-bit and 64-bit ARM
      qemu-system-arm \
      qemu-system-aarch64 \
      # qemu-user-static provides ARM user-mode emulators + registers binfmt handlers
      qemu-user-static \
      # Utilities for partitioning, mounting, etc.
      fdisk \
      mtools \
      # Basic tools
      curl \
      ca-certificates \
      python3 \
    && rm -rf /var/lib/apt/lists/*

# Copy in your QEMU launch script
COPY run-qemu.sh /usr/local/bin/run-qemu.sh
RUN chmod +x /usr/local/bin/run-qemu.sh

# Default entrypoint runs QEMU against /data/raspios.img
# Mount your host image at runtime via:
#   -v "$(pwd)/external/raspios.img":/data/raspios.img:ro
ENTRYPOINT ["/usr/local/bin/run-qemu.sh"]
