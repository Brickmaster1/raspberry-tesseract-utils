#!/usr/bin/env bash
set -euo pipefail

# A TUI for populating the `secure/` directory with all secrets and configs.

SECURE_DIR="$(pwd)/secure"
mkdir -p "$SECURE_DIR"/{ssh,wireguard,k3s,wifi}

# Ensure whiptail & openssl & curl
sudo apt-get update
sudo apt-get install -y whiptail openssl curl

# 1) Password management
PW_FILE="$SECURE_DIR/passwords.env"
> "$PW_FILE"
echo "# username=hashed_password (SHA-512)" >> "$PW_FILE"
while whiptail --yesno "Add or update a user/password?" 8 60; do
  USER=$(whiptail --inputbox "Username:" 8 40 3>&1 1>&2 2>&3)
  PASS=$(whiptail --passwordbox "Password for $USER:" 8 40 3>&1 1>&2 2>&3)
  HASH=$(openssl passwd -6 "$PASS")
  sed -i "/^$USER=/d" "$PW_FILE"
  echo "$USER='$HASH'" >> "$PW_FILE"
done

# 2) SSH setup
SSH_DIR="$SECURE_DIR/ssh"
mkdir -p "$SSH_DIR"
> "$SSH_DIR/authorized_keys"
if whiptail --yesno "Add SSH public key(s) for authorized_keys?" 8 60; then
  while whiptail --yesno "Add another key?" 8 50; do
    KEY=$(whiptail --inputbox "Paste public key:" 12 70 3>&1 1>&2 2>&3)
    echo "$KEY" >> "$SSH_DIR/authorized_keys"
  done
fi
if whiptail --yesno "Provide a custom sshd_config?" 8 50; then
  FILE=$(whiptail --fselect "~/" 20 60 3>&1 1>&2 2>&3)
  cp "$FILE" "$SSH_DIR/sshd_config"
else
  cat > "$SSH_DIR/sshd_config" <<EOF
PermitRootLogin no
PasswordAuthentication yes
EOF
fi

# 3) WireGuard configs
WG_DIR="$SECURE_DIR/wireguard"
mkdir -p "$WG_DIR"
if whiptail --yesno "Import local WireGuard .conf file(s)?" 8 60; then
  while whiptail --yesno "Add another .conf?" 8 50; do
    FILE=$(whiptail --fselect "~/" 20 60 3>&1 1>&2 2>&3)
    cp "$FILE" "$WG_DIR/"
  done
fi
if whiptail --yesno "Fetch WireGuard configs from a URL?" 8 60; then
  URL=$(whiptail --inputbox "Enter tar.gz URL:" 10 60 3>&1 1>&2 2>&3)
  curl -fsSL "$URL" | tar -xz -C "$WG_DIR"
fi

# 4) K3s token
K3S_FILE="$SECURE_DIR/k3s/token"
mkdir -p "$(dirname "$K3S_FILE")"
TOKEN=$(whiptail --passwordbox "Enter K3s node token:" 10 60 3>&1 1>&2 2>&3)
echo "$TOKEN" > "$K3S_FILE"

# 5) Wi-Fi networks
WIFI_DIR="$SECURE_DIR/wifi"
mkdir -p "$WIFI_DIR"
NETS="$WIFI_DIR/networks.conf"
SEL="$WIFI_DIR/selected.conf"
> "$NETS"
while whiptail --yesno "Add a Wi-Fi network?" 8 60; do
  SSID=$(whiptail --inputbox "SSID:" 8 50 3>&1 1>&2 2>&3)
  MODE=$(whiptail --menu "Security:" 10 50 3 WPA-PSK "WPA-PSK" OPEN "Open" 3>&1 1>&2 2>&3)
  if [ "$MODE" = "WPA-PSK" ]; then
    PSK=$(whiptail --passwordbox "PSK for $SSID:" 8 50 3>&1 1>&2 2>&3)
    wpa_passphrase "$SSID" "$PSK" >> "$NETS"
  else
    cat >>"$NETS"<<EOF
network={
    ssid="$SSID"
    key_mgmt=NONE
}
EOF
  fi
  echo >> "$NETS"
done

# Choose default network
CHOICES=(); i=1
while read -r line; do
  [[ $line =~ ssid=\"([^\"]+)\" ]] || continue
  CHOICES+=("$i" "${BASH_REMATCH[1]}" off)
  ((i++))
done < <(grep '^ssid=' -A0 "$NETS")
if [ "${#CHOICES[@]}" -gt 0 ]; then
  SELIDX=$(whiptail --radiolist "Select default Wi-Fi:" 15 60 5 "${CHOICES[@]}" 3>&1 1>&2 2>&3)
  IDX=1
  while read -r line; do
    [[ $line =~ ssid=\"([^\"]+)\" ]] || continue
    if [ "$IDX" -eq "$SELIDX" ]; then
      echo "${BASH_REMATCH[1]}" > "$SEL"
      break
    fi
    ((IDX++))
  done < <(grep '^ssid=' -A0 "$NETS")
fi

echo "Secure directory ready at: $SECURE_DIR"
