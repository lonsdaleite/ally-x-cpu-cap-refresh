#!/usr/bin/env bash
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run as root: sudo ./install.sh" >&2
  exit 1
fi

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

SCRIPT_SRC="$SCRIPT_DIR/refresh-cpu-cap.sh"
SERVICE_SRC="$SCRIPT_DIR/refresh-cpu-cap-after-power-change.service"
UDEV_SRC="$SCRIPT_DIR/99-refresh-cpu-cap-on-power.rules"

SCRIPT_DST="/usr/local/bin/refresh-cpu-cap.sh"
SERVICE_DST="/etc/systemd/system/refresh-cpu-cap-after-power-change.service"
UDEV_DST="/etc/udev/rules.d/99-refresh-cpu-cap-on-power.rules"

install -m 755 "$SCRIPT_SRC" "$SCRIPT_DST"
install -m 644 "$SERVICE_SRC" "$SERVICE_DST"
install -m 644 "$UDEV_SRC" "$UDEV_DST"

systemctl daemon-reload
udevadm control --reload-rules

echo "Installed:"
echo "  $SCRIPT_DST"
echo "  $SERVICE_DST"
echo "  $UDEV_DST"
echo
echo "Test manually:"
echo "  sudo systemctl start refresh-cpu-cap-after-power-change.service"
echo "  journalctl -u refresh-cpu-cap-after-power-change.service --since '2 minutes ago' --no-pager"
