# Slot

Slot is a tiny, native three-item clipboard ring for macOS. It keeps normal
`Command-V` behavior for a single paste, then lets you keep holding Command and
tap V again to replace that paste with the previous clipboard item.

```text
Copy A       [A]
Copy B       [B, A]
Copy C       [C, B, A]
Copy D       [D, C, B]

Hold Command:
V            paste D
V            replace D with C
V            replace C with B
V            replace B with D
Release      commit and reset
```

## Features

- Keeps the three most recent clipboard entries.
- Preserves text, rich text, images, file URLs, and other pasteboard formats.
- Cycles in place without changing the familiar `Command-V` shortcut.
- Persists the ring locally between launches.
- Ignores pasteboard items marked concealed or transient by password managers.
- Runs as a lightweight menu-bar app with no network access or dependencies.

## Requirements

- macOS 13 or newer
- Xcode command-line tools
- Accessibility permission, used to intercept and synthesize paste keystrokes

## Build

```sh
./build.sh
open build/Slot.app
```

The default build is ad-hoc signed. Developers can use a stable signing identity
so Accessibility permission survives rebuilds:

```sh
SLOT_SIGNING_IDENTITY="Apple Development: Your Name (TEAMID)" ./build.sh
```

## Install

```sh
./install.sh
```

This builds Slot, installs it at `/Applications/Slot.app`, registers a per-user
login agent, and opens the app. On first launch, enable Slot in **System Settings
→ Privacy & Security → Accessibility**.

## Usage

1. Copy normally with `Command-C`.
2. Hold Command and tap V once to paste the newest item.
3. Without releasing Command, tap V again to replace it with the previous item.
4. Continue tapping V to cycle through the ring.
5. Release Command to keep the displayed item and reset the next cycle.

Use the `▣` menu-bar icon to inspect the slots, clear them, open Accessibility
settings, or quit.

## Tests

```sh
./test.sh
```

The test suite uses a private named pasteboard and does not modify the system
clipboard.

For clipboard-format troubleshooting, `Tools/PasteboardTrace.swift` prints
pasteboard types, sizes, image dimensions, and short hashes without printing
clipboard contents.

## Privacy

Slot is completely local and makes no network requests. The three saved entries
are stored, unencrypted, at:

```text
~/Library/Application Support/Slot/slots.plist
```

Anyone or any process with access to your macOS user account may be able to read
that file. Slot excludes common concealed/transient password-manager formats,
but applications do not all label sensitive clipboard data consistently. Use
**Clear Saved Slots** when appropriate.

Diagnostics contain only timestamps, slot counts, and cycle indices and are
written to `~/Library/Logs/Slot.log`.

## How cycling works

Slot monitors `NSPasteboard` and materializes each entry's representations. It
uses a Core Graphics event tap to intercept plain `Command-V`. On repeated V
presses during the same Command hold, Slot undoes its previous paste, swaps the
pasteboard entry, and pastes again.

Because replacement depends on the destination application's undo behavior, it
works best in standard macOS text fields and editors. Terminals, remote desktop
clients, secure fields, and applications with custom undo systems may behave
differently. Releasing Command immediately ends the cycle.

## License

[MIT](LICENSE)
