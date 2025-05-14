#!/usr/bin/env bash
set -euo pipefail

# run-qemu.sh — launch Raspberry Pi 4 emulation inside Docker
# Expects the SD card image at $1 (default: /data/raspios.img)

IMG=${1:-/data/raspios.img}
echo "[run-qemu] Using image: $IMG"

# 1️) Resize image to next power-of-two bytes (avoids QEMU sizing issues)
CUR_SIZE=$(stat -c%s "$IMG")
NEXT_POW2=$(python3 - <<EOF
import math
print(2**math.ceil(math.log($CUR_SIZE, 2)))
EOF
)
if [ "$NEXT_POW2" -gt "$CUR_SIZE" ]; then
  echo "[run-qemu] Resizing $IMG to $NEXT_POW2 bytes"
  qemu-img resize "$IMG" "$NEXT_POW2"
fi

# 2️) Determine boot partition offset (bytes) via fdisk
FINFO=$(fdisk -l "$IMG" | awk '/^Device.*img1/{dev=$1} /^Units/{u=$8} END{print u}')
# fdisk may show something like "Units: sectors of 512 bytes"
# We want: offset = start_sector * sector_size
SECTOR_SIZE=$(echo "$FINFO" | awk '{print $1}')
# simpler: use parted to get offset
BOOT_OFFSET=$(parted -m "$IMG" unit B print \
  | awk -F: '$1=="1"{print $2}' | tr -d 'B')
echo "[run-qemu] Boot partition offset: $BOOT_OFFSET bytes"

# 3️) Extract DTB & kernel from the FAT boot partition using mtools
# Configure mtools drive C:
echo "drive c: file=\"$IMG\" offset=$BOOT_OFFSET" > /root/.mtoolsrc

echo "[run-qemu] Extracting DTB and kernel..."
mcopy -q -i "$IMG" ::/bcm2711-rpi-4-b.dtb /tmp/bcm2711-rpi-4-b.dtb
mcopy -q -i "$IMG" ::/kernel8.img /tmp/kernel8.img

# 4️) Enable SSH + set default user/password via userconf mechanism
# Create an empty 'ssh' file in the FAT partition
echo "[run-qemu] Enabling SSH on first boot..."
mmd -i "$IMG" ::/ssh

# Optionally override the 'pi' user's password hash via SSH_HASH env var
HASH=${SSH_HASH:-$HASH}  # if SSH_HASH is set, use it
if [ -n "${SSH_HASH-}" ]; then
  echo "[run-qemu] Installing custom password hash for user 'pi'"
  echo "pi:${SSH_HASH}" > /tmp/userconf
  mcopy -q -i "$IMG" /tmp/userconf ::/userconf
fi

# 5️) Launch QEMU as Raspberry Pi 4 Model B
echo "[run-qemu] Starting QEMU..."
exec qemu-system-aarch64 \
  -M raspi3b \                          # use raspi3b machine type for Pi4 emulation
  -cpu cortex-a72 \                     # Pi4 uses Cortex-A72 cores
  -m 1024 -smp 4 \                      # 1 GB RAM, 4 cores
  -nographic \                          # console over stdio
  -dtb /tmp/bcm2711-rpi-4-b.dtb \
  -kernel /tmp/kernel8.img \
  -sd "$IMG" \
  -append "console=ttyAMA0,115200 root=/dev/mmcblk0p2 rw rootwait" \
  -device usb-net,netdev=net0 \
  -netdev user,id=net0,hostfwd=tcp::2222-:22
