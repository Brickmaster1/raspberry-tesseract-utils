#!/usr/bin/env bash
set -euo pipefail

CACHE_IMG="external/raspios.img"
WORK="out/work"
BOOT_MNT="$WORK/boot"
ROOT_MNT="$WORK/root"
FINAL_DIR="out/img"
FINAL_IMG="$FINAL_DIR/raspios-custom.img"

OV_BOOT="patches/overlays/boot"
OV_ROOT="patches/overlays/root"

# Prepare
mkdir -p "$BOOT_MNT" "$ROOT_MNT" "$FINAL_DIR"

# 1) Download base if missing
if [ ! -f "$CACHE_IMG" ]; then
  echo "[make_image] Downloading base image..."
  TMP="$CACHE_IMG.zip"
  curl -L "https://downloads.raspberrypi.org/raspios_lite-arm64/images/latest/raspios_lite-arm64.zip" -o "$TMP"
  unzip -p "$TMP" >"$CACHE_IMG"
  rm "$TMP"
else
  echo "[make_image] Using cached image"
fi

# 2) Mount
LOOP=$(sudo losetup --show -fP "$CACHE_IMG")
sudo mount "${LOOP}p1" "$BOOT_MNT"
sudo mount "${LOOP}p2" "$ROOT_MNT"

# 3) Overlays (full copy)
echo "[make_image] Applying overlays…"
cp -rT "$OV_BOOT" "$BOOT_MNT"
cp -rT "$OV_ROOT" "$ROOT_MNT"

# 4) Patches (unified diffs) alongside overlays
echo "[make_image] Applying overlay-directory patches…"
# Boot
find "$OV_BOOT" -name '*.patch' | while read -r patch; do
  rel="${patch#$OV_BOOT/}"
  rel="${rel%.patch}"
  echo "  > Applying boot patch $rel"
  (cd "$BOOT_MNT" && patch -p1 < "$patch")
done

# Root
find "$OV_ROOT" -name '*.patch' | while read -r patch; do
  rel="${patch#$OV_ROOT/}"
  rel="${rel%.patch}"
  echo "  > Applying root patch $rel"
  (cd "$ROOT_MNT" && patch -p1 < "$patch")
done

# 5) Unmount & detach
sudo umount "$BOOT_MNT" "$ROOT_MNT"
sudo losetup -d "$LOOP"

# 6) Copy output
cp "$CACHE_IMG" "$FINAL_IMG"
echo "[make_image] Built image is at $FINAL_IMG"