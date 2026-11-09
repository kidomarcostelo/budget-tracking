# On-Device Testing from Termux

> Test Cashew on a physical Android phone using a Termux tablet as the development device.

## Overview

Since Termux cannot run the full Android SDK toolchain, APKs are built via GitHub Actions in the cloud. This guide sets up **Wireless ADB** and a one-command automation script so the full cycle — push → cloud build → download → install on phone — runs hands-free from a single terminal command.

**Total setup time:** ~15 minutes (one-time).  
**Per-iteration time:** ~4–5 minutes (hands-free after running one command).

---

## Prerequisites

| Item | Requirement |
|------|-------------|
| **Dev device** | Android tablet/phone running Termux with `gh` authenticated |
| **Test phone** | Android 11+ with Wireless Debugging support |
| **Network** | Both devices on the same Wi-Fi network |
| **GitHub** | `build-apk.yml` workflow in the repo (already present) |

---

## 1. Install Tools in Termux

```bash
pkg update && pkg upgrade -y
pkg install android-tools gh -y
```

Verify:
```bash
adb --version    # should print "Android Debug Bridge version ..."
gh auth status   # should show authenticated
```

---

## 2. Enable Wireless Debugging on the Test Phone

> [!NOTE]
> These steps are done **on the test phone**, not the Termux tablet.

1. Go to **Settings → About Phone** → tap **Build Number** 7 times to enable Developer Options.
2. Go to **Settings → Developer Options** → toggle **Wireless Debugging** ON.
3. Tap the **"Wireless Debugging"** text (not just the toggle) to open the detailed screen.
4. Note the **IP address and port** shown (e.g. `192.168.0.105:41235`) — this is the **connection port**.

---

## 3. Pair the Devices (One-Time)

On the test phone's Wireless Debugging screen:

1. Tap **"Pair device with pairing code"**.
2. Note the **pairing IP:port** and the **6-digit code** shown in the dialog. Keep this dialog open.

In Termux on the tablet:

```bash
adb pair 192.168.0.105:37201
# Enter the 6-digit pairing code when prompted
```

> [!IMPORTANT]
> The **pairing port** (shown in the pairing dialog) is different from the **connection port** (shown on the main Wireless Debugging screen). Use the pairing port for `adb pair` and the connection port for `adb connect`.

---

## 4. Connect (Every Session)

```bash
adb connect 192.168.0.105:41235
```

Verify:
```bash
adb devices
# Should show:
# 192.168.0.105:41235    device
```

> [!TIP]
> You only need to re-pair if the phone is factory reset. But you need to re-connect (`adb connect`) at the start of each session or after Wi-Fi reconnects.

---

## 5. Test the Connection

Quick test with the current APK (if you have one downloaded):

```bash
adb install -r .scratch/apk/app-debug.apk
```

Or install any APK to confirm the pipeline works end-to-end.

---

## 6. One-Command Build & Deploy

The automation script handles the full cycle:

```
git push  →  GitHub Actions build  →  download artifact  →  adb install
```

### Usage

```bash
# Push your changes first, then:
bash .scratch/build-and-deploy.sh
```

The script will:
1. Trigger the `build-apk.yml` workflow on the current branch.
2. Wait and watch the build progress in real-time.
3. Download the APK artifact when done.
4. Install it on the connected phone via `adb install`.

### Options

```bash
# Build from a specific branch
bash .scratch/build-and-deploy.sh feat/my-feature

# If ADB isn't connected, the script still downloads the APK
# and tells you where to find it for manual install.
```

### Full Workflow Example

```bash
# 1. Make changes
cd budget && vim lib/struct/receiptParser.dart

# 2. Commit and push
cd /data/data/com.termux/files/home/repo/budget-tracking
git add -A && git commit -m "fix(ocr): improve MariBank parser" && git push

# 3. Build and deploy (hands-free ~4-5 min)
bash .scratch/build-and-deploy.sh

# 4. Test on phone — app is already installed and ready to open
```

---

## Troubleshooting

### `adb devices` shows "offline" or "unauthorized"

On the test phone, a prompt should appear: **"Allow USB debugging?"** — tap **Allow**. If no prompt appears:
```bash
adb disconnect
adb connect 192.168.0.105:41235
```

### `adb pair` says "Connection refused"

- Ensure the pairing dialog is still open on the phone (it times out).
- Verify both devices are on the same Wi-Fi network.
- Check the phone's IP hasn't changed (some routers assign dynamic IPs).

### Build fails in GitHub Actions

```bash
# Check the logs
gh run view <run_id> --log-failed
```

### APK download returns empty

GitHub artifacts expire after 90 days. For recent builds:
```bash
gh run list --workflow=build-apk.yml --limit 5
gh run download <run_id> -n cashew-debug-apk -D .scratch/apk
```

### Phone Wi-Fi IP changed

Find the new IP on the phone: **Settings → Wi-Fi → tap connected network → IP address**. Then:
```bash
adb connect <new_ip>:<port>
```

---

## Fallback: Local HTTP Server

If ADB isn't available (e.g. phone runs Android < 11), serve the APK over HTTP:

```bash
cd .scratch/apk
python -m http.server 8080 --bind 0.0.0.0
```

On the phone, open Chrome and go to:
```
http://<tablet_ip>:8080/app-debug.apk
```

You'll need to allow **"Install unknown apps"** for Chrome in phone settings and dismiss the Play Protect warning.

---

## Reference

- **Script location:** [`.scratch/build-and-deploy.sh`](../../.scratch/build-and-deploy.sh)
- **CI workflow:** [`.github/workflows/build-apk.yml`](../../.github/workflows/build-apk.yml)
- **Research:** [`.scratch/research-termux-phone-testing.md`](../../.scratch/research-termux-phone-testing.md)
- **Populating test data:** [`docs/guides/populating-test-data.md`](file:///data/data/com.termux/files/home/repo/budget-tracking/docs/guides/populating-test-data.md)
- **Device verification guide:** [`docs/guides/device-verification-guide.md`](file:///data/data/com.termux/files/home/repo/budget-tracking/docs/guides/device-verification-guide.md)
