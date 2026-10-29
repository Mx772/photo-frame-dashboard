#!/system/bin/sh
# wifiwatch: some frames drop Wi-Fi and never rejoin, though the saved network is in range and
# enabled. If IFACE has had no IPv4 address for DOWN seconds, turn Wi-Fi off and on so it rejoins.
# Needs root (svc wifi). See scripts/wifiwatch/README.md.
IFACE=${IFACE:-wlan0}
DOWN=${DOWN:-180}
CHECK=${CHECK:-60}

while [ "$(getprop sys.boot_completed)" != 1 ]; do sleep 5; done
log -t wifiwatch "watching $IFACE, restarting Wi-Fi after ${DOWN}s without an address"

down=0
while true; do
  sleep $CHECK
  if ip -4 addr show $IFACE 2>/dev/null | grep -q "inet "; then
    down=0
    continue
  fi
  down=$((down + CHECK))
  if [ $down -ge $DOWN ]; then
    log -t wifiwatch "no address on $IFACE for ${down}s, restarting Wi-Fi"
    svc wifi disable
    sleep 5
    svc wifi enable
    down=0
  fi
done
