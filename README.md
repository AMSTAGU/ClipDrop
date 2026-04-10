<div align="center">
  <img src="public/Aidrop-ClipBoard-Appicon-iOS-Default-256x256@2x.png" alt="ClipDrop Icon" width="128">
  <h1>ClipDrop</h1>
</div>

A lightweight macOS menu bar app that lets you share your clipboard between Macs via AirDrop in one click.

Once launched, ClipDrop lives quietly in your menu bar, watching your Downloads folder in the background. No Dock icon, no intrusive windows — just a small icon that lets you send and receive clipboard content across your Macs instantly.

---

## Features

- **One-click share** — Send your current clipboard to a nearby Mac via AirDrop
- **Auto-copy on receive** — Incoming clipboard content is automatically copied, no interaction needed
- **Runs in the menu bar** — No Dock icon, lightweight background process
- **Smart file interception** — Prevents macOS from opening received files in TextEdit
- **Finder cleanup** — Automatically closes the AirDrop window after delivery
- **Launch at login** — Optional, configurable in settings
- **Notification support** — Get alerted when clipboard content is received

---

## How it works

ClipDrop creates a custom `.aidropclip` file containing your clipboard text and sends it via AirDrop using the native macOS sharing API. On the receiving end, it monitors your Downloads folder in real-time and processes the file the moment it arrives.

To prevent macOS from routing the file to TextEdit, ClipDrop uses a custom binary file format with a magic header (`CLIPDROP`), forcing the OS to treat it as binary data rather than plain text — making ClipDrop the exclusive handler.

```
File format:
[4 null bytes] + [CLIPDROP] + [4-byte length] + [UTF-8 text]
```

---

## Requirements

- macOS 15 (Sequoia) or later
- Two Macs with AirDrop enabled and in range

### Permissions

ClipDrop will ask for the following permissions on first launch:

| Permission | Why |
|---|---|
| Downloads folder access | To detect incoming AirDrop clipboard files |
| Notifications | To alert you when clipboard content is received |
| Apple Events | To close the Finder AirDrop window automatically |

---

## Installation

1. Download the latest release from [Releases](https://github.com/AMSTAGU/ClipDrop/releases)
2. Move `ClipDrop.app` to your `/Applications` folder
3. Launch the app — it will appear in your menu bar
4. Follow the onboarding to grant required permissions

---

## Build from source

```bash
git clone https://github.com/AMSTAGU/ClipDrop.git
cd ClipDrop
open Aidrop-Clipboard.xcodeproj
```

Select the `Aidrop-Clipboard` scheme and hit **Run** (⌘R).

---

## Usage

### Sending your clipboard

1. Copy any text on your Mac
2. Click the ClipDrop menu bar icon
3. Click **Share via AirDrop**
4. Select the target Mac in the AirDrop picker

### Receiving clipboard content

Nothing to do — ClipDrop handles it automatically. When a `.aidropclip` file lands in your Downloads folder, ClipDrop reads it, copies the text to your clipboard, and deletes the file. A notification confirms receipt.

---

## Privacy

ClipDrop never sends data to any server. Everything happens locally between your Macs over AirDrop (peer-to-peer, encrypted by Apple). No analytics, no telemetry.

---

## License

MIT
