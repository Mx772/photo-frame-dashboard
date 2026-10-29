# Dragon Touch Classic10 Charm (Frameo): root ADB over Wi-Fi and the WebView kiosk

Report from **one unit**, tested on **16–17 October 2026** using an **Apple silicon Mac,
macOS 27.0** with platform-tools 37.0.1. The owner bought it from
[Amazon US, ASIN B0GTLPX5LC](https://www.amazon.com/dp/B0GTLPX5LC?tag=webo080-20). The listing identifies the
purchase, not a guarantee that another unit has this firmware. A **second unit** from the same
listing, with the same firmware, was set up on 24 October 2026 from Linux; it adds USB ADB through a
Mini-B port, a `daemonsu` restart loop (stopped at every boot from `install-recovery.sh`) and a
Frameo auto power-off. It also dropped off Wi-Fi and did not rejoin; boot-time watchers now
restart Wi-Fi and return to the kiosk. See
[Second unit](#second-unit-usb-mini-b-and-a-daemonsu-restart-loop).

**Verified result:** root ADB was reachable over Wi-Fi with no authorization prompt, and
the shell has full root capabilities. After a private, verified backup of the critical
partitions, the repository's native kiosk (`dashboard/kiosk`) was installed and runs the
hosted dashboard full-screen through the shipped WebView 106 — no browser, no WebView
swap, no boot patch, and nothing written outside `/data`. The kiosk is the frame's only
`android.intent.category.HOME` handler, so it comes up at boot (see
[the HOME finding](#no-app-on-this-unit-claims-home)).

## Identity and observations

| Item | Observed value |
| --- | --- |
| Model in properties | `Classic10 charm` |
| Firmware build | `Classic10 charm_A33M_20260323-1608_V01` |
| Android / SDK | `6.0.1` / `23` |
| Manufacturer / board / hardware | `joyhong` / `exdroid` / `sun8i` |
| Build fingerprint | `joy/astar_ococci/astar-ococci:6.0.1/MOB30R/20260323:user/test-keys` |
| CPU ABI | `armeabi-v7a` |
| Display / density | `1280x800` / `160` |
| Stock app | Frameo, `net.frameo.frame` v1.29.14 (60300) — **not** VPhoto |
| Vendor test app | `com.joyhong.test` v2.0.34 (the owner's "ADB mode" setting lives here) |
| Vendor updater | `com.waophoto.fota` |
| Stock WebView | `106.0.5249.126` — modern; the repo kiosk runs as is |
| ADB shell identity | `uid=0(root)`, context `u:r:su:s0`, full capabilities (`CapEff: ffffffffffffffff`) |
| SELinux | Permissive |
| Other | `/sbin/busybox` present; `com.android.systemui` ships **disabled** (no status or navigation bar); no VPhoto; `pm list packages -3` empty out of the box; `/system/xbin/su` present but not setuid (untested — the shell is already root) |

This is a different model from the
[Dragon Touch Modern10 Charm](dragontouch-modern10-charm.md) (VPhoto, WebView 44) and from
the [Frameo 102K](frameo-102k-a33.md), though all three are Allwinner A33 `astar_*` boards.
The chip was not physically inspected. The partition map matches the 102K's from
`bootloader` (p2, 32 MiB at sector 73728) through `recovery` (p9); `cache` is 256 MiB and
the partitions after it sit at different offsets. The eMMC user area is 30,777,344 sectors
(15,758,000,128 bytes) — the same size as the Modern10 Charm unit. There is no p4; a
2-sector `mmcblk0p3` sits at sector 1.

## ADB access

Throughout this session TCP port 5555 was open with `service.adb.tcp.port=5555` set, and
`adb connect <frame-ip>:5555` returned a root shell immediately — no authorization prompt,
and none could appear: `com.android.systemui` is disabled, so there is no UI to show one.
The same no-AUTH-over-Wi-Fi signature was reported for the Modern10 Charm and for the
Classic15 Pro (issue #146). After one owner-initiated reboot the connection came back the
same way: root, no prompt, same address, with the FOTA disable and the enabled
accessibility service intact. `persist.sys.usb.config=mtp,adb` suggests a USB gadget
config, but the only USB port observed is a USB-A receptacle, and a USB-A-to-USB-C cable
to the Mac enumerated nothing — the same result as the Modern10 Charm report. USB ADB was
not pursued further; Wi-Fi was enough. **Wi-Fi ADB is the only way in on this unit.** Before
changing Wi-Fi settings or disabling vendor apps, check by hand on the panel that you can still
reach Android Settings (README rule 9).

**Security hand-off:** this is an unauthenticated root shell open to anyone who can reach
the frame on the network. Keep it on an isolated network (a guest or IoT network with no other
devices you care about), never port-forward it, and re-check
the ADB toggle in the vendor app (or block the port) before putting it on an untrusted
network.

## Backup

Before installing anything, the critical partitions were read over ADB and verified:
`bootloader`, `env`, `boot`, `system`, `recovery`, `misc`, `frp`, plus `mmcblk0boot0` and
`mmcblk0boot1` — checked for exact byte counts, SHA-256, gzip readback hash, and fresh
re-reads of each partition plus a 16 MiB sample 128 MiB into `system` (avoiding the mutable
ext4 superblock). All checks matched, and a second `system` sample read an hour later was
byte-identical, so the filesystem was not being written while running. `/sbin/busybox dd`
was used throughout, so the >2 GiB `dd` limit noted for the Modern10 Charm never applied.
Not captured: `UDISK` (`/data`), `cache`, and the small `metadata`, `private`, `empty`,
`alog` and `media_data` partitions — the owner-approved scope covered the static
partitions a restore would need, since the kiosk changes land in `/data`.

A pipeline trap worth recording: **this device's `adbd` appends busybox `dd`'s statistics
line to `adb exec-out` stdout** (`32+0 records in` / `32+0 records out`, 25–41 trailing
bytes depending on digit count). The payload is intact and the junk is strictly trailing,
but any exact-size `cmp` against the stream phantom-fails unless the stream is truncated
to the partition's exact size first (`… | head -c <size> | cmp - image`). Small partitions
"match" by accident because both sides carry the same tail; a sliced compare against a
clean range is where it bites. Trimming the saved images to their exact sizes and
re-verifying produced the matching hashes.

## No app on this unit claims HOME

The complete `dumpsys package` output contains **zero** `android.intent.category.HOME`
filters on this build — Frameo included — and `<preferred-activities />` in
`package-restrictions.xml` is empty. Frameo ships a `BOOT_COMPLETED` receiver
(`net.frameo.frame/.core.BootCompleteReceiver`) — that, not HOME, is how it starts itself
at boot. The boot "Welcome, <name>" screen the owner saw before the disable is gone after
a reboot (owner-confirmed; the receiver is the presumed source). The HOME intent
always resolves to the kiosk once the kiosk's alias is enabled. Frameo is disabled and its
data cleared on this unit (owner-approved; see the change table), so neither path runs.
Consequences:

- After installing the kiosk and running it with the `home` extra, it is the **only**
  HOME handler: no chooser ever appears and `am start -c android.intent.category.HOME`
  goes straight to the kiosk. (On the 102K, Frameo claims HOME and a chooser appears.)
- With `com.android.systemui` disabled there is no navigation bar, so the kiosk's
  accessibility **Home HQ navigation** service (floating Back/Dashboard buttons) is the
  only way back from other apps. Enabled with root:

  ```sh
  adb shell pm grant com.wesbos.homehq android.permission.WRITE_SECURE_SETTINGS
  adb shell settings put secure enabled_accessibility_services com.wesbos.homehq/com.wesbos.homehq.NavigationService
  adb shell settings put secure accessibility_enabled 1
  ```

  The service was confirmed bound (`dumpsys accessibility`) and the buttons visible in a
  Settings screenshot outside the kiosk. The two-finger gesture was confirmed by the owner
  on the panel, not by screencap — injected touch does not prove input here, and screencaps
  alone do not either (README rule 9).

## What was set up (all owner-approved writes)

| Change | Undo |
| --- | --- |
| `adb install -r dashboard/kiosk/build/homehq.apk` (built from this repo, `minSdk 23`) | `adb uninstall com.wesbos.homehq` |
| Dashboard URL saved and HOME alias enabled: `am start -n com.wesbos.homehq/.MainActivity --es url <url> --ez home true` (demo URL in this trial) | `am start -n com.wesbos.homehq/.MainActivity --ez home false` |
| `WRITE_SECURE_SETTINGS` grant, so the kiosk re-adds its navigation service itself | `pm revoke com.wesbos.homehq android.permission.WRITE_SECURE_SETTINGS` |
| Accessibility service enabled (commands above) | disable in Settings → Accessibility |
| `pm disable com.waophoto.fota` (updater disabled while the frame is online) | `pm enable com.waophoto.fota` |
| Optional and destructive: `pm clear net.frameo.frame` (wipes the setup name and all Frameo data; only needed to remove the boot "Welcome" screen). Then `pm disable net.frameo.frame` (kills its `BOOT_COMPLETED` autostart). The boot "Welcome" screen is gone after a reboot — owner-confirmed | `pm enable net.frameo.frame` (data is not restored; re-setup re-asks the name) |
| `settings put global stay_on_while_plugged_in 7` (previous value `0`) | `adb shell settings put global stay_on_while_plugged_in 0` |

The dashboard was verified rendering full-screen by screenshot after install. The clock
was checked against the host twice (after install and after a reboot): correct date, time
and timezone both times — but the Modern10 Charm's clock-jump behaviour may only strike
occasionally, and this unit's `idle` time exceeding `uptime` after a reboot shows the same
underlying quirk, so a wrong date can still present as a silent calendar bug. The owner
has confirmed on the panel that the two-finger hold opens the kiosk menu and that the
dashboard comes back by itself after a reboot; the floating Back/Dashboard buttons were
additionally visible in a Settings screenshot. The vendor test app (`com.joyhong.test`)
remains installed and enabled; Frameo is disabled with its data cleared.

## Not tested

- Factory-reset behaviour and firmware restore (backups exist; restore is unproven).
- USB ADB through other cables, or the `mtp,adb` gadget config on a device-mode port.
- A second computer with a fresh ADB key (the no-key-check observation is one host only).
- Whether other units from this listing ship this firmware.
- Long-term behaviour beyond one owner reboot: FOTA staying disabled, the navigation
  service surviving force-stops of the kiosk (it did survive one reboot), and network
  ADB after a change of Wi-Fi network or DHCP address.

## Second unit: USB Mini-B and a `daemonsu` restart loop

Report from a **second unit** from the same listing (ASIN B0GTLPX5LC), set up on
**24 October 2026** from **Debian 13** in a Proxmox VM (the frame passed through by USB port),
with Debian's `adb` 34.0.5. Every identity value in [the table above](#identity-and-observations)
matched: model, build, fingerprint, SDK 23, `joyhong/exdroid/sun8i`, 1280x800 at 160, WebView
106.0.5249.126, Frameo v1.29.14 (60300), root shell with full capabilities, SELinux Permissive,
`systemui` disabled, no third-party packages, and the same partition map and eMMC size.

### USB ADB works through the Mini-B port

The frame has a **USB Mini-B** port as well as the USB-A socket. With a Mini-B cable it enumerated
as `1f3a:1007` "Android USB Developer" with an ADB interface (`ff/42/01`), and `adb shell` was root
straight away, with no prompt (none could show: `systemui` is disabled). So on this unit Wi-Fi ADB
is not the only way in. On Linux it needed a udev rule for the Allwinner vendor ID:

```sh
echo 'SUBSYSTEM=="usb", ATTR{idVendor}=="1f3a", MODE="0660", GROUP="plugdev"' \
  | sudo tee /etc/udev/rules.d/51-android-allwinner.rules
sudo udevadm control --reload && sudo udevadm trigger
```

`service.adb.tcp.port=5555` was set out of the box here too, so the unauthenticated root shell on
port 5555 appears on whatever network the frame joins (see the security hand-off above). Wi-Fi was
not configured when it arrived.

### Frameo powers the frame off

While Frameo was running, the frame shut itself down every few minutes, which dropped the USB
connection mid-backup. Each shutdown was preceded by Frameo starting
`net.frameo.frame/.core.ui.APowerOffNotice`, and its preferences count them (`POWER_OFF_TIMES`,
`POWER_OFF_REASON`). `am force-stop net.frameo.frame` did not help: Frameo was running again within
a second. `pm disable net.frameo.frame` stopped the shutdowns. Frameo also held three root shells
open through SuperSU (`daemonsu:10002`, `tmp-mksh`), which closed when it was disabled.

### `daemonsu` restarts every 5 seconds and remounts `/system`

The first `system` image failed its device-side hash check. Only the first 64 MiB differed, and it
changed on every read: the ext4 superblock's mount count went from 881 to over 1,100 in about an
hour, and `/sys/fs/ext4/mmcblk0p7/session_write_kbytes` grew by about 7 kB/s, although no file on
`/system` changed (`find -newer build.prop` found only Frameo's factory licence files from
2026-03-26). `/proc/mounts` showed `/system` read-only in every namespace, but
`/proc/fs/ext4/mmcblk0p7/options` showed the filesystem itself read-write.

The cause is the init service `daemonsu`, stuck at `init.svc.daemonsu=restarting`. Every ~5 s init
starts it, it remounts `/system` several times (`EXT4-fs (mmcblk0p7): re-mounted` in `dmesg`) and
reloads the SELinux policy (`auditd: type=1403 … policy loaded`), then exits with status 0 because
the real `daemonsu` is already running, and init starts it again. It continued with Frameo and the
updater disabled. So the frame is constantly writing `/system`'s superblock and journal. The same
loop is recorded on the [VTimes VT01001](vtimes-vt01001.md), the
[Uhale A33](uhale-a33-astar-d7.md#backup-and-the-daemonsu-remount-loop) and the
[SKYRHYME 168](skyrhyme-168.md); all three stopped it only until the next reboot.

For the backup, `setprop ctl.stop daemonsu` stopped the loop until the next reboot. The root ADB
shell is unaffected (`adbd` runs as root itself). The mount count then held still and `system`
passed every check. **A `system` backup will not verify while the loop runs.** The first unit's
16 MiB sample, taken 128 MiB into `system`, avoided the changing region.

#### Stopping it at every boot without touching `boot`

The service is defined in the boot ramdisk (`/init.rc:761`,
`service daemonsu /system/xbin/daemonsu --auto-daemon`, no `oneshot`). Adding `oneshot` there is the
clean fix, but a bad `boot` image on an A33 frame needs the FEL route in
[allwinner-a33-boot-access.md](allwinner-a33-boot-access.md) to recover. Instead, the stop was added
to a script init already runs once, as root, at every boot: `/init.rc:691`
`service flash_recovery /system/bin/install-recovery.sh` (`class main`, `oneshot`). Nothing checks
`/system` at boot on this firmware (no `verify` in `/fstab.sun8i`, no verity properties), and if
the script fails, Android boots as before with the loop running.

The vendor's lines were kept unchanged and this was appended:

```sh
i=0
while [ "$(getprop init.svc.daemonsu)" != restarting ] && [ $i -lt 120 ]; do
  sleep 1
  i=$((i + 1))
done
if [ "$(getprop init.svc.daemonsu)" = restarting ]; then
  setprop ctl.stop daemonsu
  log -t daemonsu-fix "stopped daemonsu restart loop after ${i}s"
else
  log -t daemonsu-fix "daemonsu not restarting after ${i}s; left alone"
fi
```

It waits for `restarting` so `daemonsu:master` is already up; the master keeps running after the
stop. It runs in the foreground on purpose: when a service's main process exits, init kills its
process group, so a background `&` would be killed with it.

How it was written, with the loop already stopped by hand so nothing remounted `/system` mid-write:
the new file was pushed to `/data/local/tmp`, checked with `sh -n`, the appended part run on its
own once (it stopped the live loop), then in one shell: `mount -o remount,rw /system`,
`cp -p install-recovery.sh install-recovery.sh.bak`, `cat new > install-recovery.sh` (keeps the
inode, mode `0750` and the `u:object_r:install_recovery_exec:s0` label), `sync`,
`mount -o remount,ro /system`, then the SHA-256 of both files checked.

After a reboot: logcat showed `recovery: Recovery image already installed` (the vendor's check
still runs) and then `daemonsu-fix: stopped daemonsu restart loop after 0s`, 6.7 s into boot.
`init.svc.daemonsu` was `stopped`, `dmesg` had 4 `re-mounted` lines from the master's own start and
none after, and over 60 s the `system` mount count and `session_write_kbytes` did not change. The
kiosk came up as usual. **Undo:** remount `/system` read-write and
`cat /system/bin/install-recovery.sh.bak > /system/bin/install-recovery.sh`. Tested across one
reboot on one unit.

### Wi-Fi drops and does not rejoin

Four days after setup the frame was found offline in the morning. It had been off Wi-Fi since at
least 02:40, and for over 5 hours it scanned every 15 s, saw its saved network each time
(`SCAN_RESULTS_EVENT … known=1` in `dumpsys wifi`) and never tried to join it. Tapping the network
in Settings joined it at once. Signal was strong (-25 to -36 dBm). `networkHistory.txt` showed the
network enabled (`AUTO_JOIN_STATUS: 0`), with 0 connect, authentication and IP failures and
`VALIDATED_INTERNET_ACCESS: true`, so Android had not disabled it. The screen stays on
(`mStayOn=true`), so this was not screen-off scanning. The reboot needed to recover ADB cleared
the logs from the time of the drop, so the cause is unknown.

Two side findings:

- **Leaving Settings was impossible.** With `systemui` disabled there is no navigation bar, and
  the navigation service was not bound (see [below](#other-differences-from-the-first-unit)).
  `input keyevent KEYCODE_HOME` did nothing either, because `device_provisioned` and
  `user_setup_complete` were both `0` (the setup wizard never finished), and Android ignores Home
  until setup is complete. After `settings put global device_provisioned 1` and
  `settings put secure user_setup_complete 1`, the Home key returned to the kiosk.
- **Long `dumpsys wifi | grep` pipelines over Wi-Fi ADB** hung once and left `adbd` stuck
  (`device offline`, port 5555 still accepting connections) until the frame was power cycled.
  Read files such as `/data/misc/wifi/networkHistory.txt` instead.

### Watchers and navigation at every boot

Three additions run from the same `install-recovery.sh`, appended after the `daemonsu` block:

- [`scripts/wifiwatch`](../scripts/wifiwatch/README.md) turns Wi-Fi off and on after 3 minutes
  without an address. A test run of `svc wifi disable`, 5 s, `svc wifi enable` rejoined in about 4 s.
- [`scripts/kioskwatch`](../scripts/kioskwatch/README.md) returns to the kiosk after 2 minutes
  with no touch in another app. The touchscreen here is `gslX680`, the script's default.
- A navigation fix: reinstalling the same kiosk APK binds the navigation service, so it is done
  once at boot if the service is not bound.

```sh
# Android does not bind the kiosk's navigation service after a reboot on this unit, but
# reinstalling the same APK binds it within seconds. Check once, 30 s after boot.
(
  while [ "$(getprop sys.boot_completed)" != 1 ]; do sleep 5; done
  sleep 30
  if dumpsys accessibility | grep -q "Home HQ navigation"; then
    log -t navfix "navigation service bound; nothing to do"
  else
    apk=$(pm path com.wesbos.homehq)
    # chmod: this script's umask leaves the copy unreadable to the package manager.
    cp "${apk#package:}" /data/local/tmp/navfix.apk && chmod 0644 /data/local/tmp/navfix.apk
    log -t navfix "navigation service not bound, reinstalling ${apk#package:}: $(pm install -r /data/local/tmp/navfix.apk 2>&1)"
    rm -f /data/local/tmp/navfix.apk
  fi
) &

# Watchers, until shutdown: kioskwatch returns to the kiosk after 2 minutes with no touch in
# another app; wifiwatch turns Wi-Fi off and on if it has no address for 3 minutes. Last and in
# the foreground for the same reason as above.
/system/bin/sh /system/bin/kioskwatch.sh &
exec /system/bin/sh /system/bin/wifiwatch.sh
```

`kioskwatch.sh` and `wifiwatch.sh` were copied to `/system/bin` (mode `0755`). Because init kills
the service's process group when the script exits, the script never exits: `exec` turns it into
`wifiwatch`, and `init.svc.flash_recovery` stays `running`. Without the `chmod`, `pm install`
failed with `INSTALL_FAILED_INVALID_APK`. SELinux logs `avc: denied` for kioskwatch's touch stamp
in `/data/local/tmp`, which permissive mode allows.

Each script was first run from `/data/local/tmp` (wifiwatch with a missing interface and `svc`
replaced by `log`; kioskwatch with `IDLE=20`, which left Wi-Fi settings after 30 s). After the
install, across 3 reboots (`adb shell reboot` works on this unit), logcat showed
`wifiwatch: watching wlan0` and `kioskwatch: watching /dev/input/event5` once boot completed.
After the last one it showed `navfix: … Success`, with `dumpsys accessibility` listing
**Home HQ navigation**. The Back/Dashboard bar was drawn above Wi-Fi settings. The kiosk stayed in
front through the reinstall. Not yet seen: wifiwatch handling a real drop.
**Undo:** remount `/system` read-write,
`cat /system/bin/install-recovery.sh.before-watchers > /system/bin/install-recovery.sh`, delete
`/system/bin/kioskwatch.sh` and `/system/bin/wifiwatch.sh`, remount read-only and reboot.

### Other differences from the first unit

- **The clock starts in 1969** (`Wed Dec 31 19:00 EST 1969`) until the frame reaches network time.
  It was correct within a minute of joining Wi-Fi.
- **The navigation service did not survive a reboot.** After each of two reboots,
  `dumpsys accessibility` showed `services:{}` with `accessibilityEnabled=false`, although
  `enabled_accessibility_services` and `accessibility_enabled=1` were both still set. The kiosk
  logged "Navigation service listed but not running, rebinding", but Android never bound it.
  Neither re-writing the two settings from ADB nor disabling and re-enabling the component helped;
  `adb install -r` of the kiosk bound it within 3 s every time. The first unit kept it across one
  reboot. Setting `device_provisioned` and `user_setup_complete` to `1` did not change this.
  Worked around by reinstalling the APK at boot
  ([watchers and navigation at every boot](#watchers-and-navigation-at-every-boot)); the cause is
  unknown.
- **Portrait** works with the kiosk's `--es orientation portrait` setting
  ([kiosk README](../dashboard/kiosk/README.md#orientation)); the `mir3da` accelerometer flips it
  the right way up.
- **BusyBox** here has no `nc` or `timeout`, and its `wget` cannot resolve names (Android has no
  `/etc/resolv.conf`); use IP addresses when testing from the frame's shell.
- **On an isolated IoT network** the kiosk needs only TCP from the frame to the dashboard host and
  port. One allow rule (with return traffic) was enough; other hosts and ports stayed blocked.

### Changes on this unit (all owner-approved)

| Change | Undo |
| --- | --- |
| Verified backup of `bootloader`, `env`, `boot`, `system`, `recovery`, `misc`, `frp`, `mmcblk0boot0`, `mmcblk0boot1` (size, device-side SHA-256, full re-read, gzip readback) | — |
| `pm disable net.frameo.frame` (data **not** cleared) | `pm enable net.frameo.frame` |
| `pm disable com.waophoto.fota` | `pm enable com.waophoto.fota` |
| `setprop ctl.stop daemonsu` (until reboot) | reboot, or `setprop ctl.start daemonsu` |
| `/system/bin/install-recovery.sh`: appended a boot-time stop for the `daemonsu` loop ([details](#stopping-it-at-every-boot-without-touching-boot)); original kept as `install-recovery.sh.bak` | remount `/system` rw, `cat install-recovery.sh.bak > install-recovery.sh` |
| Kiosk installed, URL saved, `--ez home true`, `--es orientation portrait`, `WRITE_SECURE_SETTINGS` grant, navigation service enabled | as in [the first unit's table](#what-was-set-up-all-owner-approved-writes) |
| `settings put global stay_on_while_plugged_in 7` (previous value `0`) | `settings put global stay_on_while_plugged_in 0` |
| `settings put global device_provisioned 1` and `settings put secure user_setup_complete 1` (both were `0`), so the Home key works ([details](#wi-fi-drops-and-does-not-rejoin)) | set both back to `0` |
| `/system/bin/install-recovery.sh`: appended the navigation fix, `kioskwatch` and `wifiwatch` ([details](#watchers-and-navigation-at-every-boot)); previous version kept as `install-recovery.sh.before-watchers`; `kioskwatch.sh` and `wifiwatch.sh` added to `/system/bin` | see **Undo** in that section |

After a reboot the kiosk came back by itself in portrait, with Frameo and the updater still
disabled. `com.joyhong.test` was left enabled, as on the first unit.
