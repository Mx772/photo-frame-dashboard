#!/usr/bin/env bash
# Build the guarded boot-write script for the SD card. Run in Linux (or WSL) from the repository
# root (uses the mkimage that build.sh produced). See docs/allwinner-a33-sdcard-adb-wifi.md.
#   bash scripts/a33-sdboot/build-write.sh apply
#   bash scripts/a33-sdboot/build-write.sh restore
# apply:   writes boot-patched.img, only if p6 still equals boot-original.img
# restore: writes boot-original.img back, only if p6 equals boot-patched.img
# Inputs come from diagnostics/pf1007/patched/ (made by scripts/a33-sdboot/patch-boot.py). Output:
# diagnostics/pf1007/patched/sdcard-<mode>/{a33.scr,<image>}. Writes nothing to any device.
set -euo pipefail

MODE="${1:?usage: build-write.sh apply|restore}"
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
P="$ROOT/diagnostics/pf1007/patched"
MKIMAGE="$ROOT/diagnostics/a33-sdboot/build/tools/mkimage"
# The PF1007L's boot image. For another board with p6 at the same sector, set BOOT_LEN and
# BOOT_SHA256 to that board's original image (the values patch-boot.py was given).
LEN="${BOOT_LEN:-15886336}"
ORIG_SHA="${BOOT_SHA256:-d71c313ddaa4693948acb20af7740ccb56c88bf9376746a47fce2d00c14fc6a4}"
[[ "$LEN" =~ ^[0-9]+$ ]] && [ $((LEN % 512)) = 0 ] || { echo "FAIL: BOOT_LEN must be a whole number of 512-byte sectors" >&2; exit 1; }
[[ "$ORIG_SHA" =~ ^[0-9a-f]{64}$ ]] || { echo "FAIL: BOOT_SHA256 must be 64 lowercase hex digits" >&2; exit 1; }

case "$MODE" in
  apply)   NEW=boot-patched.img;  OLD=boot-original.img ;;
  restore) NEW=boot-original.img; OLD=boot-patched.img ;;
  *) echo "mode must be apply or restore" >&2; exit 1 ;;
esac

# The original must still be the image cut from the verified dump.
[ "$(sha256sum < "$P/boot-original.img" | cut -d' ' -f1)" = \
  "$ORIG_SHA" ] \
  || { echo "FAIL: boot-original.img is not the backed-up image" >&2; exit 1; }
for f in "$NEW" "$OLD"; do
  [ "$(stat -c %s "$P/$f")" = "$LEN" ] || { echo "FAIL: $f is not $LEN bytes" >&2; exit 1; }
done
[ -x "$MKIMAGE" ] || { echo "FAIL: no mkimage at $MKIMAGE (run build.sh first)" >&2; exit 1; }

SHA_NEW="$(sha256sum < "$P/$NEW" | cut -d' ' -f1)"
SHA_OLD="$(sha256sum < "$P/$OLD" | cut -d' ' -f1)"
[ "$SHA_NEW" != "$SHA_OLD" ] || { echo "FAIL: images are identical" >&2; exit 1; }

OUT="$P/sdcard-$MODE"
rm -rf "$OUT"; mkdir -p "$OUT"
cp "$P/$NEW" "$OUT/$NEW"
sed -e "s/@FILE@/$NEW/g" \
    -e "s/@OLD_NAME@/$OLD/g" \
    -e "s/@STATUS@/a33-write-status.txt/g" \
    -e "s/@SIZE_HEX@/$(printf '%x' "$LEN")/g" \
    -e "s/@SECTORS_HEX@/$(printf '%x' $((LEN / 512)))/g" \
    -e "s/@SHA_NEW@/$SHA_NEW/g" \
    -e "s/@SHA_OLD@/$SHA_OLD/g" \
    "$HERE/boot-write.cmd.in" > "$OUT/boot-write.cmd"
! grep -q '@[A-Z_]*@' "$OUT/boot-write.cmd" || { echo "FAIL: unfilled placeholder" >&2; exit 1; }
"$MKIMAGE" -q -A arm -T script -C none -n "a33 boot $MODE" -d "$OUT/boot-write.cmd" "$OUT/a33.scr"
cd "$OUT"
sha256sum a33.scr "$NEW" | tee SHA256SUMS
ls -l
