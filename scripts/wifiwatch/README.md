# wifiwatch: rejoin Wi-Fi when a frame stops trying (rooted frames)

On a [Dragon Touch Classic10 Charm](../../docs/dragontouch-classic10-charm.md#wi-fi-drops-and-does-not-rejoin)
the frame dropped off Wi-Fi overnight and stayed off for over 5 hours. It scanned every 15 s and
saw its saved network each time, but never tried to join it. The saved network was not disabled
and had no connect, authentication or DHCP failures. Joining it by hand in Settings worked at once.

`wifiwatch.sh` checks every `CHECK` seconds (default 60) whether `IFACE` (default `wlan0`) has an
IPv4 address. After `DOWN` seconds (default 180) without one, it runs `svc wifi disable`, waits
5 s and runs `svc wifi enable`. Android then rejoins the saved network by itself; on the Charm
that took about 4 s. It logs to logcat with tag `wifiwatch`.

It turns Wi-Fi back on even if someone turned it off on purpose. Stop the script first if you
need Wi-Fi off.

## Try it without changing /system

```sh
adb push scripts/wifiwatch/wifiwatch.sh /data/local/tmp/
adb shell 'IFACE=wlan9 DOWN=20 CHECK=5 timeout 40 sh /data/local/tmp/wifiwatch.sh'
adb shell 'logcat -d -s wifiwatch'
```

`wlan9` doesn't exist, so it restarts Wi-Fi after 20 s, and ADB over Wi-Fi drops for a few
seconds. Use the USB connection if the frame has one.

## Start it at boot

Start it from a script that init runs as root at every boot, such as
`/system/bin/install-recovery.sh`. If that script is an init service (`service flash_recovery`
in `init.rc`), init kills everything it started when it exits, so a line ending in `&` is not
enough: start the script last and in the foreground. The Classic10 Charm's
[boot block](../../docs/dragontouch-classic10-charm.md#watchers-and-navigation-at-every-boot) does this.
