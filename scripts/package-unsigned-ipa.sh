#!/usr/bin/env bash
set -euo pipefail

if (( $# < 2 || $# > 3 )); then
  echo "usage: $0 <base-unsigned.ipa> <output.ipa> [MCMIdentifiers.plist]" >&2
  exit 64
fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BASE_IPA="$(python3 -c 'import os,sys; print(os.path.abspath(sys.argv[1]))' "$1")"
OUTPUT_IPA="$(python3 -c 'import os,sys; print(os.path.abspath(sys.argv[1]))' "$2")"
CATALOG="${3:-}"
if [[ -n "$CATALOG" ]]; then
  CATALOG="$(python3 -c 'import os,sys; print(os.path.abspath(sys.argv[1]))' "$CATALOG")"
  plutil -lint "$CATALOG"
  plutil -extract AppData xml1 -o /dev/null "$CATALOG"
fi
cd "$REPO_ROOT"
test -s "$BASE_IPA"
test -s .theos/obj/FilzaApplySandboxExt.dylib
test "$(lipo -archs .theos/obj/FilzaApplySandboxExt.dylib)" = arm64
test -s ThirdParty/mond-current/Resources/MondEmbedded.bundle/Info.plist
test -s ThirdParty/3105/Resources/Filza3105.bundle/UpstreamAppInfo.plist
test -d .theos/byetunes-appintents/Metadata.appintents
bash scripts/stage-byetunes-resources.sh .theos/byetunes-resources

STAGE="$(mktemp -d "${TMPDIR:-/tmp}/filza-unsigned.XXXXXX")"
trap 'rm -rf "$STAGE"' EXIT
unzip -q "$BASE_IPA" -d "$STAGE"
APP="$(find "$STAGE/Payload" -maxdepth 1 -type d -name '*.app' -print -quit)"
test -n "$APP"
test "$(plutil -extract CFBundleIdentifier raw -o - "$APP/Info.plist")" = com.apple.mobile.MobileHouseArrest
# The archive is a resource/binary base only; do not retain its privileged identity.
plutil -replace CFBundleIdentifier -string com.hubzzzgr.FilzaWorseQuery "$APP/Info.plist"
plutil -replace FilzaAccessBackend -string worse_query "$APP/Info.plist"
while IFS= read -r -d '' extension_plist; do
  plutil -replace CFBundleIdentifier -string \
    "com.hubzzzgr.FilzaWorseQuery.$(basename "$(dirname "$extension_plist")" .appex)" "$extension_plist"
done < <(find "$APP/PlugIns" -name Info.plist -print0)
python3 scripts/patch-plist-search.py "$APP"
EXECUTABLE="$(plutil -extract CFBundleExecutable raw -o - "$APP/Info.plist")"
test -s "$APP/$EXECUTABLE"
# The pinned base is already linked to this injected library. Never run it.
otool -L "$APP/$EXECUTABLE" > "$STAGE/load-commands.txt"
grep -Fq 'FilzaApplySandboxExt.dylib' "$STAGE/load-commands.txt"
mkdir -p "$APP/Frameworks"
cp .theos/obj/FilzaApplySandboxExt.dylib "$APP/Frameworks/FilzaApplySandboxExt.dylib"
rm -f "$APP/Frameworks/FilzaMondModern.dylib"

for resource in AppIconImage.png ByeTunes-Info.plist Config.plist; do
  test -s ".theos/byetunes-resources/$resource"
  cp ".theos/byetunes-resources/$resource" "$APP/$resource"
done
rm -rf "$APP/MondEmbedded.bundle" "$APP/Filza3105.bundle" "$APP/Metadata.appintents"
cp -R ThirdParty/mond-current/Resources/MondEmbedded.bundle "$APP/"
cp -R ThirdParty/3105/Resources/Filza3105.bundle "$APP/"
cp -R .theos/byetunes-appintents/Metadata.appintents "$APP/"
mkdir -p "$APP/ThirdPartyNotices"
cp ThirdParty/worse_query/LICENSE "$APP/ThirdPartyNotices/worse_query-LICENSE"

plutil -replace MinimumOSVersion -string 17.0 "$APP/Info.plist"
if [[ -n "${GITHUB_RUN_NUMBER:-}" ]]; then
  plutil -replace CFBundleVersion -string "$GITHUB_RUN_NUMBER" "$APP/Info.plist"
fi
plutil -replace UIFileSharingEnabled -bool YES "$APP/Info.plist"
plutil -replace LSSupportsOpeningDocumentsInPlace -bool YES "$APP/Info.plist"
plutil -replace NSSupportsLiveActivities -bool YES "$APP/Info.plist"
plutil -replace NSSupportsLiveActivitiesFrequentUpdates -bool YES "$APP/Info.plist"
plutil -replace UIBackgroundModes -json '["audio"]' "$APP/Info.plist"
plutil -replace NSLocalNetworkUsageDescription -string \
  "Filza 27 uses your local network when you enable its WebDAV or SSH/SFTP server." "$APP/Info.plist"
plutil -replace NSBonjourServices -json '["_http._tcp","_ssh._tcp"]' "$APP/Info.plist"
bash scripts/merge-3105-app-metadata.sh "$APP/Info.plist"
python3 - "$APP/Info.plist" <<'PYINFO'
import plistlib, sys
p=sys.argv[1]
with open(p,'rb') as f: info=plistlib.load(f)
info['UIApplicationShortcutItems']=[x for x in info.get('UIApplicationShortcutItems',[]) if 'music' not in str(x.get('UIApplicationShortcutItemType','')).lower()]
with open(p,'wb') as f: plistlib.dump(info,f)
PYINFO
plutil -remove CFBundleURLTypes "$APP/Info.plist" 2>/dev/null || true

# This declares the adapter's group choice only. The sideloading signer must
# separately provision the matching App Group entitlement; CI does not sign.
if [[ -n "${FILZA_WORSE_QUERY_APP_GROUP:-}" ]]; then
  [[ "$FILZA_WORSE_QUERY_APP_GROUP" == group.?* ]] || {
    echo "FILZA_WORSE_QUERY_APP_GROUP must start with group." >&2; exit 65;
  }
  plutil -replace FilzaWorseQueryAppGroup -string "$FILZA_WORSE_QUERY_APP_GROUP" "$APP/Info.plist"
else
  plutil -remove FilzaWorseQueryAppGroup "$APP/Info.plist" 2>/dev/null || true
fi
rm -f "$APP/MCMIdentifiers.plist"
if [[ -n "$CATALOG" ]]; then cp "$CATALOG" "$APP/MCMIdentifiers.plist"; fi

# Strip all Mach-O signatures, including ad-hoc signatures from the toolchain.
while IFS= read -r -d '' binary; do
  if file -b "$binary" | grep -q 'Mach-O'; then
    if codesign -d "$binary" >/dev/null 2>&1; then
      codesign --remove-signature "$binary"
    fi
    if codesign -d "$binary" >/dev/null 2>&1; then
      echo "Signature still present: $binary" >&2; exit 70
    fi
  fi
done < <(find "$APP" -type f -print0)
find "$APP" -type d -name _CodeSignature -prune -exec rm -rf {} +
find "$APP" -name embedded.mobileprovision -type f -delete
plutil -lint "$APP/Info.plist"
test "$(plutil -extract MinimumOSVersion raw -o - "$APP/Info.plist")" = 17.0
mkdir -p "$(dirname "$OUTPUT_IPA")"
rm -f "$OUTPUT_IPA"
(cd "$STAGE" && zip -qry "$OUTPUT_IPA" Payload)
unzip -tq "$OUTPUT_IPA"
shasum -a 256 "$OUTPUT_IPA"
