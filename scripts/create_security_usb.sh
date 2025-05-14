#!/usr/bin/env bash
set -euo pipefail

# Copy everything from secure/ onto a mounted USB

if [ -z "${1-}" ]; then
  echo "Usage: $0 <usb-mount-point>"
  exit 1
fi
USB="$1"
[ -d "$USB" ] || { echo "Mount point $USB not found"; exit 1; }

rsync -a --chmod=600 secure/ "$USB/"

echo "All secure data copied to $USB"
