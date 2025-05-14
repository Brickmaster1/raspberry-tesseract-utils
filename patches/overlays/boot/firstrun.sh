#!/bin/bash
set -e

# 1) Wait for security USB
USB=""
MNT="/mnt/usb"
while [ -z "$USB" ]; do
  for d in /dev/sd?1; do
    mkdir -p "$MNT"
    if mount "$d" "$MNT" 2>/dev/null && [ -f "$MNT/passwords.env" ]; then
      USB="$MNT" && break
    fi
    umount "$MNT" 2>/dev/null
  done
  [ -z "$USB" ] && echo "Waiting for security USB..." && sleep 5
done

# 2) Import users/passwords
while IFS='=' read -r u p; do
  [[ "$u" =~ ^# ]] && continue
  id "$u" &>/dev/null || useradd -m -s /bin/bash "$u"
  echo "$u:$p" | chpasswd -e
done < "$USB/passwords.env"

# 3) SSH config
# after the loop, $u holds the *last* username read—if you need per-user SSH
# you may want to loop again over secure/ssh/<user>/*. For now we install one:
if [ -f "$USB/ssh/sshd_config" ]; then
  cp "$USB/ssh/sshd_config" /etc/ssh/sshd_config
fi
if [ -f "$USB/ssh/authorized_keys" ]; then
  # apply to each user in passwords.env
  while IFS='=' read -r user _; do
    [[ "$user" =~ ^# ]] && continue
    mkdir -p /home/"$user"/.ssh
    cp "$USB/ssh/authorized_keys" /home/"$user"/.ssh/
    chown -R "$user":"$user" /home/"$user"/.ssh
    chmod 600 /home/"$user"/.ssh/authorized_keys
  done < "$USB/passwords.env"
fi
if [ -f /usr/lib/raspberrypi-sys-mods/imager_custom ]; then
  /usr/lib/raspberrypi-sys-mods/imager_custom enable_ssh
else
  systemctl enable ssh
fi

# 4) Copy Wi-Fi configs
if [ -d "$USB/wifi" ]; then
  mkdir -p /etc/wpa_supplicant
  cp "$USB/wifi/networks.conf" /etc/wpa_supplicant/wpa_supplicant.conf
  if [ -f "$USB/wifi/selected.conf" ]; then
    SSID=$(<"$USB/wifi/selected.conf")
    awk "/network/ { block=1 } block { if (\$0 ~ /ssid=\"$SSID\"/) print; next } { print }" \
      /etc/wpa_supplicant/wpa_supplicant.conf \
      > /etc/wpa_supplicant/wpa_supplicant_selected.conf
    mv /etc/wpa_supplicant/wpa_supplicant_selected.conf \
       /etc/wpa_supplicant/wpa_supplicant.conf
  fi
  systemctl enable wpa_supplicant
fi

# 5) Unmount USB
umount "$USB"

# 6) Register pi-wifi-setup.service
cat >/etc/systemd/system/pi-wifi-setup.service <<EOF
[Unit]
Description=Reapply Wi-Fi config from security USB if present
After=local-fs.target network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/pi_wifi_setup.sh

[Install]
WantedBy=multi-user.target
EOF
systemctl enable pi-wifi-setup.service

# 7) Register deferred pi-custom-setup.service
cat >/etc/systemd/system/pi-custom-setup.service <<EOF
[Unit]
Description=Custom Raspberry Pi Setup (VPN, K3s…)
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/pi_setup.sh
RemainAfterExit=true

[Install]
WantedBy=multi-user.target
EOF
systemctl enable pi-custom-setup.service

exit 0
