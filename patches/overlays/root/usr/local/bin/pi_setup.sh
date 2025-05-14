#!/bin/bash
set -euo pipefail

### 1. Wait for network-online ###
timeout=60
while ! hostname -I >/dev/null 2>&1 && (( timeout-- )); do sleep 1; done
[ "$timeout" -gt 0 ] || { echo "Network failed"; exit 1; }

### 2. Determine next hostname ###
get_next_hostname(){
  local base="raspberry" max=0 subnets hosts num
  subnets=$(ip -o -4 addr show scope global | awk '{print $4}')
  for net in $subnets; do
    mapfile -t hosts < <(nmap -sn -n "$net" | awk '/Nmap scan report/{print $5}')
    for h in "${hosts[@]}"; do
      if [[ $h =~ ^${base}([0-9]+)$ ]]; then
        num=${BASH_REMATCH[1]}; (( num>max )) && max=$num
      fi
    done
  done
  echo "${base}$((max+1))"
}

NEW=$(get_next_hostname)
echo "$NEW" >/etc/hostname
sed -i "s/^127\.0\.1\.1.*/127.0.1.1\t$NEW/" /etc/hosts
hostnamectl set-hostname "$NEW"

### 3. WireGuard ###
N=${NEW#raspberry}
SRC="/etc/wireguard/Pi${N}.conf"
[ ! -f "$SRC" ] && SRC="/etc/wireguard/Default.conf"
if [ -f "$SRC" ]; then
  cp "$SRC" /etc/wireguard/wg0.conf
  chmod 600 /etc/wireguard/wg0.conf
  systemctl enable wg-quick@wg0 && systemctl start wg-quick@wg0
  sleep 5
fi

### 4. K3s join ###
TOKEN_FILE="/etc/rancher/k3s/token"
[ -r "$TOKEN_FILE" ] || { echo "Missing token"; exit 1; }
TOKEN=$(<"$TOKEN_FILE")

find_control(){
  local subnets found
  subnets=$(ip -o -4 addr show scope global | awk '{print $4}')
  for net in $subnets; do
    found=$(nmap -p 6443 --open -n "$net" | awk '/6443\/open/{print $2;exit}')
    [ -n "$found" ] && { echo "$found"; return; }
  done
}

CTRL=$(find_control) || { echo "No control"; exit 1; }
curl -sfL https://get.k3s.io \
  | K3S_URL="https://${CTRL}:6443" K3S_TOKEN="$TOKEN" \
    INSTALL_K3S_EXEC="--node-name=${NEW}" sh -

systemctl disable pi-custom-setup.service
exit 0
