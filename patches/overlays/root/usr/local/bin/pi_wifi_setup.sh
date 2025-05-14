#!/bin/bash
set -e

MNT="/mnt/usb"
USB=""

# Wait until the correct USB with wifi config is found
while [ -z "$USB" ]; do
  for dev in /dev/sd?1; do
    mkdir -p "$MNT"
    if mount "$dev" "$MNT" 2>/dev/null && [ -f "$MNT/wifi/networks.conf" ]; then
      USB="$MNT"
      break
    fi
    umount "$MNT" 2>/dev/null
  done
  [ -z "$USB" ] && echo "Waiting for security USB with Wi-Fi config..." && sleep 5
done

echo "Applying Wi-Fi configuration from $USB"

# Copy Wi-Fi config to system location
mkdir -p /etc/wpa_supplicant
cp "$USB/wifi/networks.conf" /etc/wpa_supplicant/wpa_supplicant.conf

# Apply selected network filter, if requested
if [ -f "$USB/wifi/selected.conf" ]; then
  SSID=$(<"$USB/wifi/selected.conf")
  awk "/network/ { block=1 } block { if (\$0 ~ /ssid=\"$SSID\"/) print; next } { print }" \
    /etc/wpa_supplicant/wpa_supplicant.conf \
    > /etc/wpa_supplicant/wpa_supplicant_selected.conf
  mv /etc/wpa_supplicant/wpa_supplicant_selected.conf /etc/wpa_supplicant/wpa_supplicant.conf
fi

# Enable and restart wpa_supplicant to apply new config
systemctl enable wpa_supplicant
systemctl restart wpa_supplicant

# Clean up
umount "$USB"

exit 0
