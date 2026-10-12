#!/bin/zsh
# Builds a Developer ID signed, notarized and stapled Dock-Plus.dmg.
#
# Needs: a "Developer ID Application" certificate in the login keychain, and an App Store Connect
# API key for notarization in these environment variables:
#   ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_FILE (path to the AuthKey_<id>.p8 file)
# Usage: scripts/release.sh [output-dir]   (default: dist/)
#
# Builds outside the project folder: Spotlight stamps Finder metadata onto bundles inside it,
# which makes codesign fail with "resource fork, Finder information, or similar detritus".
set -euo pipefail

cd "${0:A:h}/.."
out="${1:-dist}"
work="$(mktemp -d)"
identity="Developer ID Application"

: "${ASC_KEY_ID:?set ASC_KEY_ID}" "${ASC_ISSUER_ID:?set ASC_ISSUER_ID}" "${ASC_KEY_FILE:?set ASC_KEY_FILE}"

xcodegen generate --quiet
swiftlint --quiet

# Universal (Apple silicon + Intel): the current SDK defaults to arm64 only.
# CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO keeps get-task-allow out, which notarization rejects.
xcodebuild -project DockPlus.xcodeproj -scheme DockPlus -configuration Release \
  -derivedDataPath "$work/build" ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO \
  CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY="$identity" PROVISIONING_PROFILE_SPECIFIER="" \
  CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO OTHER_CODE_SIGN_FLAGS="--timestamp" build | tail -1

app="$work/build/Build/Products/Release/Dock+.app"
codesign --verify --strict --deep "$app"
lipo -archs "$app/Contents/MacOS/Dock+"

mkdir -p "$work/dmg" "$out"
ditto "$app" "$work/dmg/Dock+.app"
ln -s /Applications "$work/dmg/Applications"
hdiutil create -volname "Dock+" -srcfolder "$work/dmg" -ov -format UDZO "$out/Dock-Plus.dmg" >/dev/null
codesign --sign "$identity" --timestamp "$out/Dock-Plus.dmg"

xcrun notarytool submit "$out/Dock-Plus.dmg" --key "$ASC_KEY_FILE" --key-id "$ASC_KEY_ID" \
  --issuer "$ASC_ISSUER_ID" --wait
xcrun stapler staple "$out/Dock-Plus.dmg"
spctl -a -t open --context context:primary-signature -v "$out/Dock-Plus.dmg"
shasum -a 256 "$out/Dock-Plus.dmg"
