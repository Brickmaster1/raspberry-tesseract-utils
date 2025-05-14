#!/usr/bin/env bash
set -euo pipefail

IMG="$1"; DEV="$2"; JSON="${3-}"

if [ ! -f "$IMG" ]; then echo "Image $IMG not found"; exit 1; fi

CMD=(rpi-imager --cli --first-run-script=firstrun.sh)
[ -n "$JSON" ] && CMD+=(--oscustomization="$JSON")
CMD+=("$IMG" "$DEV")

echo "Flashing: ${CMD[*]}"
"${CMD[@]}"
