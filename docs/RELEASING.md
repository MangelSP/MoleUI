# Releasing MoleUI

How to cut a new version and (optionally) ship a **signed + notarized** build so it
opens without Gatekeeper warnings.

MoleUI is distributed **outside the Mac App Store** (it needs to spawn CLI tools and read
the filesystem, which the App Sandbox forbids). Notarization is separate from the App
Store and keeps all of that working.

---

## 1. Bump the version

Edit the version in **two** places, then regenerate the Xcode project:

- `scripts/genproj.py` → `MARKETING_VERSION` (e.g. `1.2.0`) and `CURRENT_PROJECT_VERSION` (bump the integer)
- `MoleUI/Info.plist` → `CFBundleShortVersionString` and `CFBundleVersion`

```bash
plutil -replace CFBundleShortVersionString -string "1.2.0" MoleUI/Info.plist
plutil -replace CFBundleVersion -string "3" MoleUI/Info.plist
python3 scripts/genproj.py
```

## 2. Build Release

```bash
xcodebuild -project MoleUI.xcodeproj -scheme MoleUI -configuration Release build
APP=$(ls -d ~/Library/Developer/Xcode/DerivedData/MoleUI-*/Build/Products/Release/MoleUI.app | head -1)
```

---

## 3. Sign + notarize (requires Apple Developer Program — $99/yr)

One-time setup:

1. In Xcode → Settings → Accounts, add your Apple ID and create a **Developer ID
   Application** certificate (or download it from the Developer portal). Find its identity:
   ```bash
   security find-identity -v -p codesigning
   # → "Developer ID Application: Your Name (TEAMID)"
   ```
2. Store a notarization credential in the keychain (use an **app-specific password** from
   appleid.apple.com, not your real password):
   ```bash
   xcrun notarytool store-credentials moleui-notary \
     --apple-id "you@example.com" --team-id "TEAMID" --password "xxxx-xxxx-xxxx-xxxx"
   ```

Per release:

```bash
IDENTITY="Developer ID Application: Your Name (TEAMID)"

# Sign deep, with hardened runtime + a secure timestamp.
codesign --force --deep --options runtime --timestamp \
  --entitlements MoleUI/MoleUI.entitlements \
  --sign "$IDENTITY" "$APP"

# Verify the signature.
codesign --verify --strict --verbose=2 "$APP"

# Zip for notarization (ditto preserves the bundle).
ditto -c -k --keepParent "$APP" MoleUI.zip

# Submit and wait.
xcrun notarytool submit MoleUI.zip --keychain-profile moleui-notary --wait

# Staple the ticket onto the app so it validates offline.
xcrun stapler staple "$APP"
xcrun stapler validate "$APP"

# Re-zip the STAPLED app for distribution.
ditto -c -k --keepParent "$APP" MoleUI-1.2.0.zip
```

> The app has **App Sandbox off** and **Hardened Runtime on** — that's the correct combo
> for a notarized, non-App-Store utility. Spawning `mo`/`lsof`/`ps`/`nettop` works fine
> under Hardened Runtime; no extra entitlements are needed.

If you skip this section, the app still works — users just right-click → **Open** on first
launch (that's what the current community releases do).

---

## 4. Commit, tag, and publish

```bash
git add -A && git commit -m "vX.Y.Z — <summary>"
git push
git tag -a vX.Y.Z -m "MoleUI vX.Y.Z"
git push origin vX.Y.Z

gh release create vX.Y.Z MoleUI-1.2.0.zip --title "MoleUI vX.Y.Z" --notes "…"
```

Keep the credit to the upstream [Mole](https://github.com/tw93/mole) project intact, and
keep the license **GPL-3.0**.
