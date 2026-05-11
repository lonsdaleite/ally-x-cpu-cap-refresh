#!/usr/bin/env bash
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run as root: sudo ./uninstall.sh" >&2
  exit 1
fi

rm -f /usr/local/bin/refresh-cpu-cap.sh
rm -f /etc/systemd/system/refresh-cpu-cap-after-power-change.service
rm -f /etc/udev/rules.d/99-refresh-cpu-cap-on-power.rules

# Runtime lock file.
rm -f /run/refresh-cpu-cap.lock

systemctl daemon-reload
udevadm control --reload-rules

echo "Uninstalled."
