#!/bin/bash
# Convert the theos .deb into a sideloadable .ipa for the jailbroken device.
set -e

THEOS="${THEOS:-$HOME/theos}"
if [ ! -d "$THEOS" ]; then
    echo "ERROR: set \$THEOS to your theos install (e.g. export THEOS=\$HOME/theos)"
    exit 1
fi

echo "==> Building package"
make clean
make package FINALPACKAGE=1

DEB=$(ls -t packages/*.deb 2>/dev/null | head -n1)
if [ -z "$DEB" ]; then echo "ERROR: no .deb was produced"; exit 1; fi

echo "==> Packaging $DEB into Minesweeper.ipa"
rm -rf /tmp/ms_ipa && mkdir -p /tmp/ms_ipa/Payload
dpkg-deb -x "$DEB" /tmp/ms_ipa
APP=$(find /tmp/ms_ipa -name "Minesweeper.app" -maxdepth 5 -type d | head -n1)
if [ -z "$APP" ]; then echo "ERROR: Minesweeper.app not found in package"; exit 1; fi
cp -R "$APP" /tmp/ms_ipa/Payload/
( cd /tmp/ms_ipa && zip -r -q Minesweeper.ipa Payload )
cp /tmp/ms_ipa/Minesweeper.ipa .

echo "==> Done: Minesweeper.ipa"
