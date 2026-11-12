# Minesweeper (native, jailbroken iPad Mini 4)

A native iOS Minesweeper written in **Objective-C / UIKit**, built with
[theos](https://github.com/theos/theos). It compiles to a real `.app`, and the
included `build_ipa.sh` turns it into a sideloadable `.ipa` you can install on a
jailbroken device with no App Store and no provisioning profile.

## Features
- All-English UI (Beginner / Intermediate / Expert).
- Tap to reveal, **long-press to flag**, tap a revealed number to **chord**.
- First click is always safe; live mine counter + timer; win/lose states.
- Works on iOS 9–15 (iPad Mini 4 range), portrait & landscape.

## Requirements
- A machine with **theos** installed (macOS with Xcode, or Linux).
- An **iOS SDK** available to theos:
  - macOS: theos auto-detects Xcode's SDK.
  - Linux: drop an SDK into `$THEOS/sdks/` (e.g. `iPhoneOS.sdk`).
- `dpkg-deb` and `zip` for the `.ipa` step (both standard on macOS/Linux).

## Build

```bash
export THEOS=$HOME/theos
cd Minesweeper-ipa

# Refresh the app icon (optional, already generated)
python3 generate_icon.py

# Build the .deb (then turn it into Minesweeper.ipa).
# IMPORTANT: the binary MUST be code-signed with ldid, or iOS will refuse to
# launch it on the jailbroken device (even with AppSync, a missing/placeholder
# signature is the #1 cause of "installs but won't open"). The build signs
# automatically as long as ldid is present at $THEOS/bin/ldid — do NOT set
# THEOS_NO_LDID=1.
make clean
make package FINALPACKAGE=1
./build_ipa.sh
```

`build_ipa.sh` also runs `make package` internally, so the two-step
`make package` + `./build_ipa.sh` above is equivalent to just `./build_ipa.sh`.

> **ldid is required.** If you see `Signing …` during the build, you're good.
> If signing is skipped or errors, copy ldid into theos first:
> `cp "$THEOS/toolchain/linux/iphone/bin/ldid" "$THEOS/bin/ldid"` (Linux),
> or `brew install ldid` / use theos' bundled one (macOS).

## Install on the jailbroken iPad Mini 4

**Option A — Filza (easiest, no computer needed after transfer):**
1. Get `Minesweeper.ipa` onto the iPad (AirDrop, email, SMB, SFTP…).
2. Open it with **Filza** → tap **Install**. It lands in `/Applications`.
3. Respring (Filza has a button, or run `uicache` / `sbreload` in a terminal
   app like NewTerm).

**Option B — SSH install via theos:**
1. In `Makefile`, set `THEOS_DEVICE_IP` (and `THEOS_DEVICE_PORT` if needed).
2. `make package install` — theos copies the `.deb` over SSH and runs
   `uicache` automatically (see the `after-install` hook).

Because the device is jailbroken, the `.ipa` does **not** need an Apple
developer account — but it still needs a (fake) `ldid` code-signature so iOS
will launch it. `build_ipa.sh` produces an already-signed `Minesweeper.ipa`.
(If you prefer, installing **AppSync Unified** from your package manager also
makes iOS accept unsigned apps.)

## Project layout
```
Minesweeper-ipa/
├── Makefile                  # theos application build
├── control                   # Debian package metadata
├── generate_icon.py          # icon.png generator (stdlib only)
├── build_ipa.sh              # .deb -> Minesweeper.ipa
├── layout/Applications/Minesweeper.app/
│   ├── Info.plist
│   └── icon.png
└── Sources/
    ├── main.m
    ├── AppDelegate.h / .m
    ├── MinesweeperModel.h / .m   # game logic
    ├── MSTile.h / .m             # tile button
    └── GameViewController.h / .m # UI + input
```

## Troubleshooting
- `Makefile:…: /application.mk: No such file or directory` → theos was not found.
  The build needs `THEOS` pointing at your theos install. Set it explicitly:
  ```bash
  export THEOS=$HOME/theos      # or wherever theos lives
  ```
  This Makefile also auto-detects `~/theos`, `/opt/theos`, `/usr/local/theos`
  and `/var/theos`. Verify with: `ls $THEOS/makefiles/common.mk`.
  If that `ls` fails, theos is not installed yet — see **Installing theos** below.
- macOS build needs an iOS SDK (Xcode provides one). On Linux, place an SDK at
  `$THEOS/sdks/iPhoneOS.sdk`. The fastest path is theos' own
  `install-sdk latest` (used here → `iPhoneOS16.5.sdk`).
- **App installs but won't open / crashes on launch** → almost always a missing
  code signature. Make sure the build printed `==> Signing Minesweeper…` (i.e.
  ldid ran). If it printed `Signing` was skipped, you built with
  `THEOS_NO_LDID=1` — rebuild without it, with ldid at `$THEOS/bin/ldid`.
  Installing **AppSync Unified** is an alternative if you can't sign.

## Installing theos (Linux Mint / Debian, build host)
```bash
sudo apt update
sudo apt install -y git curl fakeroot perl unzip xz-utils build-essential libtinfo6
git clone --recursive https://github.com/theos/theos.git "$THEOS"

# iOS SDK (patched):
"$THEOS/bin/install-sdk" latest

# iOS clang toolchain (Linux): the official one is ~86 MB and some proxies
# drop the single-shot download. A resumable chunked downloader is included:
python3 dl_toolchain.py          # -> /home/mint/iOS.tar.xz
mkdir -p "$THEOS/toolchain"
tar -xJf /home/mint/iOS.tar.xz -C "$THEOS/toolchain/"
```
Verify: `"$THEOS/toolchain/linux/iphone/bin/clang" --version` should print
`clang version 11.1.0`. If the direct `curl` of the toolchain keeps failing
with `502 Bad Gateway`, the chunked `dl_toolchain.py` (HTTP Range requests)
works around the proxy and resumes where it left off.
(If `libtinfo6` isn't found, drop it.)

## Notes
- Want **Swift** instead? The same theos setup supports `APPLICATION_NAME`
  with `.swift` files and `Minesweeper_SWIFT_VERSION = 5.0`; the logic was kept
  in Objective-C for the broadest iOS 9+ compatibility on the A8 chip.
- To target a different board size, edit `kPresets` in `GameViewController.m`.
