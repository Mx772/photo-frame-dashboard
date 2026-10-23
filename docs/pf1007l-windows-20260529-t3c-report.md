# PF1007L May `20260529` on Windows: T3c, then a full native-Windows setup

One USB-C-only PF1007 on `V10-1680.0.20260529` (AiMOR 6.0.78), taken from stock to a
dashboard kiosk **entirely from native Windows** — `adb` and Python run on Windows; WSL
Ubuntu was used only to build the kiosk APK. This confirms the existing T3c +
`persist.sys.usb.config` route for this firmware ([#117](https://github.com/wesbos/photo-frame-dashboard/issues/117),
[#163](https://github.com/wesbos/photo-frame-dashboard/issues/163)) and adds the downstream
full-setup steps (backup, WebView 106, CA roots, launcher, floating navigation, kiosk as Home)
with several Windows- and device-specific gotchas that are not yet written down.

No boot partition was written. Nothing private is included (no serial, MAC, IP, Wi-Fi details or
whole-eMMC hash).

## Report

```text
About model / firmware: PF1007 (About screen); firmware YHK.F-null-A33-1001-D1024-PF1007L-V10-1680.0.20260529
AiMOR version: 6.0.78
Ports (DC jack, or USB-C only): USB-C only, microSD slot, reset + power buttons
Cable and port that gave USB data: USB-A to USB-C data cable in a direct USB-A port on the PC
T3 USB IDs seen / adb devices output: 1f3a:1000 "USB Mass Storage Device"; adb devices empty
T3b network ADB result (port 5555): refused (ping OK, TCP 8086 open)
T4 / T5: skipped (T3c succeeded)
eMMC size in sectors: 30,777,344
Boot partition start sector: 172032 (boot -> mmcblk0p6)
Boot image SHA-256 (sector 172032, 31,028 sectors): 6c118dc1aa583797884c33cd3ac3796c72b2bd3a3f1fcafd1bf0982ae5f29e2c
Route used and result: T3c (AiMOR vendor channel) via a TP-Link Deco DHCP primary-DNS entry pointing
  at the PC, scripts/aimor-network-adb dns.py + server.py on Windows; uid=0(root) over Wi-Fi, then
  setprop persist.sys.usb.config mass_storage,adb -> persistent root USB ADB (1f3a:1002), survived a
  power-cycle. No boot/partition write.
Host OS: Windows 11 (adb 37.0.1 / platform-tools, Python 3.14; WSL Ubuntu only for the kiosk build)
First failed step and its exact output: none (T3 and T3b failed as expected for a stock-ADB-off unit)
```

## Access (T3c), confirming #117/#163

- Stock `1f3a:1000`, no ADB; TCP 5555 refused. T3c was the route.
- The home network is a **TP-Link Deco**. As in #163, Deco's WAN DNS field rejects a LAN address, so
  the redirect was set under **Advanced -> DHCP Server -> Primary DNS = <PC LAN IP>** (secondary blank).
  To keep the frame off the vendor the whole time, this plus `dns.py`'s allowlist was used so the
  frame could not resolve anything until its address was explicitly allowed.
- `dns.py` + `server.py` ran unmodified on Windows (the `os.geteuid` guard from #183 is in place).
  `server.py` sent the one command `setprop service.adb.tcp.port 5555; stop adbd; start adbd`;
  `adb connect` then returned `uid=0(root)`.
- `setprop persist.sys.usb.config mass_storage,adb` gave root USB ADB that survived a power cut
  (confirmed again here, as in #117). After that the DNS entry was cleared and the frame taken off
  Wi-Fi; nothing else depends on the vendor channel.

## Full backup over USB root ADB — a verification caveat

Backed up the whole eMMC in 512 MiB chunks with the frame's `/sbin/busybox dd` (stock `dd` returns
0 bytes past 2 GiB on this firmware). Worth recording for anyone scripting a backup check:

- A **whole-device checksum comparison is not a valid integrity test on a live, mounted frame.**
  Re-reading `/dev/block/mmcblk0` a second time (e.g. `busybox md5sum`) will not match the captured
  image, because Android keeps writing the mutable partitions (`UDISK`, `cache`, `metadata`, `alog`,
  `media_data`) during the ~1 h read. This is expected, not corruption.
- Verify transfer integrity on the **static** partitions instead: an independent re-read of
  `bootloader`, `env`, `boot`, `system`, `misc`, `recovery` matched the captured image byte-for-byte,
  the boot image's 31,028-sector SHA-256 matched the row above, and a gzip decompress-readback matched.
  The mutable partitions are only ever a best-effort snapshot over ADB.

## WebView 106 swap — two device notes

Followed the `/system` swap in `allwinner-a33-pf1007l.md` section 6 (stock WebView was 44.0.2403.119).
After reboot `com.android.webview` reported `106.0.5249.126`, logcat showed
`cr_WVCFactoryProvider: Loaded version=106.0.5249.126 isBundle=false` with no `dlopen` errors, and the
kiosk rendered. Two things specific to this unit:

- **`find -exec ... {} +` silently does nothing** here — the device's `find` takes `\;`, not `+`.
  The guide's `find $NEW -type f -exec chmod 644 {} +` left files at `0666`/dirs at `0777`; set the
  modes with explicit `chmod` on the paths instead and re-check `ls -l`.
- Chromium logs `eglChooseConfig failed ... EGL_BAD_ATTRIBUTE` (Mali-400, old GL driver) and falls
  back to **software rendering**. The dashboard still renders fine; keep heavy continuous animation off.

## CA roots

The demo host `home-dashboard.wesbos.workers.dev` chains leaf -> GTS WE1 -> **GTS Root R4** ->
GlobalSign, so **GTS Root R4** (`5acf816d.0`) is the anchor the old store is missing. Added GTS R1,
GTS R4 and ISRG Root X1 per the [Uhale guide](si006-uhale.md) table (pinned DER SHA-256), mode 0644,
root:root. **SELinux is Disabled** on this unit (the existing cacerts show as `unlabeled`), so no
context fix was needed. After restarting the kiosk the hosted dashboard loaded over HTTPS with no
cert error.

## Floating navigation needs the kiosk to be Home

This firmware has no SystemUI (no status/navigation bar), so the kiosk's accessibility service
("Home HQ navigation", floating Back/Dashboard buttons) is the only standalone way out of another
app. One finding worth adding to the kiosk README's PF1007L note:

- The buttons **do not survive a reboot on their own.** After boot, `enabled_accessibility_services`
  still lists the service but `accessibility_enabled` reverts to `0`, and
  `settings put secure accessibility_enabled 1` alone does **not** stick — it only sticks when Home HQ
  actually runs and re-arms the service (with the `WRITE_SECURE_SETTINGS` grant). Home HQ has no
  boot receiver, so nothing starts it at boot until it is the **Home app**. Making the kiosk Home
  (Android 6 chooser -> Home HQ -> Always) fixed it: Home HQ launches at boot, re-arms the service,
  and the buttons are present on every boot. Reboot-confirmed.

## Windows host tips

- **Byte-exact `adb exec-out` capture:** PowerShell `Start-Process -RedirectStandardOutput` corrupted
  the binary (a 1 MiB read came back as 826 bytes). `cmd /c "adb ... exec-out \"...\" > file"` and
  Python `subprocess` with `stdout=<file handle>` were both byte-exact.
- **Git Bash path mangling:** MSYS rewrites a bare `/data/...` argument to a Windows path, so
  `adb push <host> /data/local/tmp/x` fails with `remote No such file or directory`. Set
  `MSYS_NO_PATHCONV=1` (command strings with spaces, like `adb shell "busybox dd ... "`, are unaffected).
- Kiosk build toolchain on Windows via WSL with **no sudo**: a portable setup worked — `openjdk-17`
  from apt, then Android `cmdline-tools` + `build-tools;34.0.0` + `platforms;android-34` unpacked under
  `~/android-sdk`, then `ANDROID_HOME=~/android-sdk bash dashboard/kiosk/build.sh`.

## Result

Root USB ADB (persistent), AiMOR / `com.yhk.qeota` / `com.DeviceTest` disabled (confirmed
`enabled="2"` and no `:7806` after reboot), Rootless Launcher plus the kiosk's floating navigation,
WebView 106, the three CA roots, and the kiosk as Home booting straight into the dashboard. A full
verified backup was taken first.
