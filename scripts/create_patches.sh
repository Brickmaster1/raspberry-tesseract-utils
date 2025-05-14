#!/usr/bin/env bash
set -euo pipefail

# Usage: create_patches.sh <overlay-path>
# e.g.: create_patches.sh patches/overlays/boot/firstrun.sh

OVERLAY="$1"
[ -f "$OVERLAY" ] || { echo "File $OVERLAY not found"; exit 1; }

# Determine partition by the first path segment after patches/overlays/
PART=$(echo "$OVERLAY" | awk -F/ '{print $3}')
if [[ "$PART" != "boot" && "$PART" != "root" ]]; then
  echo "Cannot infer partition from path. Should be patches/overlays/{boot,root}/..." >&2
  exit 1
fi

# Locate the original file inside the stock image
IMG="external/raspios.img"
TMPDIR=$(mktemp -d)
if [ "$PART" = "boot" ]; then
  OFFSET=$((512*8192))  # adjust if your boot starts at a different sector
  mkdir -p "$TMPDIR/part"
  sudo mount -o loop,offset=$OFFSET "$IMG" "$TMPDIR/part"
  ORIG="$TMPDIR/part/$(basename "$OVERLAY")"
elif [ "$PART" = "root" ]; then
  # Replace ROOT_START_SECTOR with your image's actual root partition start
  ROOT_START_SECTOR=24576
  OFFSET=$((512*ROOT_START_SECTOR))
  mkdir -p "$TMPDIR/part"
  sudo mount -o loop,offset=$OFFSET "$IMG" "$TMPDIR/part"
  # Drop the leading 'patches/overlays/root/' from OVERLAY to get relative path
  REL="${OVERLAY#patches/overlays/root/}"
  ORIG="$TMPDIR/part/$REL"
fi

[ -f "$ORIG" ] || { echo "Original file $ORIG not found in image"; exit 1; }

# Compute patch
PATCH="${OVERLAY}.patch"
diff -u "$ORIG" "$OVERLAY" > "$PATCH" || true

echo "Patch written to $PATCH"

# Cleanup
sudo umount "$TMPDIR/part"
rm -rf "$TMPDIR"
