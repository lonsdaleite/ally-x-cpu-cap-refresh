# Ally X amd-pstate CPU cap refresh workaround

Workaround for an `amd-pstate-epp` / CPPC enforcement issue observed on ASUS ROG Xbox Ally X / Bazzite.

## Symptom

After plugging or unplugging the charger, CPU boost / CPU frequency caps may stop being enforced.

Observed state:

- `amd-pstate-epp` active
- `boost=0`
- `scaling_max_freq=2000000`
- CPPC request still has `MAX=77`
- real frequency measured via APERF/MPERF can jump to ~4-5 GHz on some cores

Manually changing `scaling_max_freq` from `2000000` to `1970000` and then back to `2000000` restores cap enforcement until the next AC/DC transition.

## What this workaround does

On every `power_supply` change event, systemd starts a oneshot service.

The service runs a script that waits 3 seconds before doing anything. This delay is important because AC0/BAT0 events arrive first, while later USB-C/PD/EC events can arrive around 1-2 seconds later. Running the refresh too early may not help.

After the delay, the script briefly changes `scaling_max_freq`:

```text
current -> current - 30000 -> current
```

On this device, `2000000 -> 1970000` changes effective CPPC MAX from `77 -> 76`, which is enough to make the firmware/SMU enforce the CPU cap again.

## Repository files

The repo contains:

- `refresh-cpu-cap.sh` - the actual workaround script
- `refresh-cpu-cap-after-power-change.service` - systemd oneshot service
- `99-refresh-cpu-cap-on-power.rules` - udev rule that starts the service on power source changes
- `install.sh` - installs the script, service, and udev rule
- `uninstall.sh` - removes installed files
- `README.md` - this document

## Install

Run from the repo directory:

```bash
sudo ./install.sh
```

The install script copies files to:

- `/usr/local/bin/refresh-cpu-cap.sh`
- `/etc/systemd/system/refresh-cpu-cap-after-power-change.service`
- `/etc/udev/rules.d/99-refresh-cpu-cap-on-power.rules`

It also reloads systemd and udev rules.

## Manual test

Start the service manually:

```bash
sudo systemctl start refresh-cpu-cap-after-power-change.service
```

Check logs:

```bash
journalctl -u refresh-cpu-cap-after-power-change.service --since "2 minutes ago" --no-pager
```

Expected successful log:

```text
Refreshing CPU cap: 2000000 -> 1970000 -> 2000000
Done.
```

`Skipped: cooldown` is normal when several `power_supply` events arrive in a short burst.

## Check udev events

Run:

```bash
udevadm monitor --kernel --udev --property --subsystem-match=power_supply
```

Then plug or unplug the charger.

Expected events should contain:

```text
SYSTEMD_WANTS=refresh-cpu-cap-after-power-change.service
TAGS=:systemd:
```

## Check automatic trigger

After plugging or unplugging the charger, wait around 4-5 seconds, then check:

```bash
journalctl -u refresh-cpu-cap-after-power-change.service --since "2 minutes ago" --no-pager
```

If the workaround is working, the service should run automatically after the power source change.

## Verify CPU frequency behavior

Use your APERF/MPERF measurement script after a charger plug/unplug event.

Expected behavior after the workaround runs:

- real APERF/MPERF frequency should stay near the configured cap
- `scaling_max_freq` should return to its original value
- no sustained ~4-5 GHz boost should remain when boost is disabled and max freq is capped

## Uninstall

Run from the repo directory:

```bash
sudo ./uninstall.sh
```

The uninstall script removes installed files and reloads systemd and udev rules.

## Notes

This is a workaround, not a root-cause fix.

Current understanding:

- AC/DC transition does not trigger normal amd-pstate/cpufreq trace events.
- `CPPC_REQ`, `CPPC_CAP1`, and `HWCR CPB_DIS` do not appear to change.
- APERF/MPERF confirms that the high frequencies are real, not just a `scaling_cur_freq` reporting issue.
- A real effective CPPC MAX transition, for example `77 -> 76 -> 77`, restores cap enforcement.
- The 3-second delay is needed because later USB-C/PD/EC events can arrive after the initial AC0/BAT0 power events.
