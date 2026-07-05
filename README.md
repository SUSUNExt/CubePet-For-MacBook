# MacBookPet

A tiny native macOS desktop pet prototype.

- Transparent floating window
- Black rounded square body
- Glowing white expression eyes
- Click to cycle expressions
- Drag to move
- Right-click for Reset Mood and Quit
- Earn 1G for every five minutes the pet stays running
- Buy food to level up the current pet
- Use all built-in pets without purchasing them
- Unlock additional cat skins with in-game coins
- Customize official pets or create a pet from imported PNG artwork

Run it with:

```bash
./script/build_and_run.sh
```

## Build a DMG

Create a release build and a drag-to-Applications installer:

```bash
./script/package_dmg.sh
```

The output is written to `dist/CubePet-<version>-<architecture>.dmg`.
Without an Apple Developer ID certificate, the script applies an ad-hoc
signature. That is suitable for local testing, but other Macs may show a
Gatekeeper warning. For public distribution, set `CODESIGN_IDENTITY` to a
Developer ID Application certificate and notarize the resulting DMG.

## GitHub upload

Commit the project source to the repository:

- `Package.swift`
- `Sources/`
- `Assets/`
- `script/`
- `.gitignore`
- `README.md`

Do not commit `.build/`, `dist/`, `.codex/`, `.DS_Store`, or generated DMG
files. Attach the DMG separately to a GitHub Release so users can install the
app without downloading the source repository.
