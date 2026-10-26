#!/bin/zsh
# release-ota.sh — build the app and publish it to a static OTA install page
# on your own server (iOS over-the-air install via itms-services).
#
# Required environment:
#   OTA_TOKEN     directory name for this app under the install root
#   OTA_SSH_HOST  ssh host of the server that hosts the install page
#   OTA_BASE_URL  public base URL of the install area, e.g. https://example.com/install
#   OTA_ROOT      absolute path of the install area on that server
#
# Optional environment:
#   APP              display name / scheme (default: Fathom)
#   BUNDLE_ID        bundle identifier used in the manifest (default: com.example.fathom)
#   DEVELOPMENT_TEAM your Apple Developer team id (passed to xcodebuild)
#   BUNDLE_ID_SETTING  overrides PRODUCT_BUNDLE_IDENTIFIER at build time
#   EXTRA_BUILD_SETTINGS  space-separated extra KEY=value build settings
#                         (use this to inject release-time secrets and URLs
#                         that project.yml references; never commit them)
#   ASC_KEY_PATH / ASC_KEY_ID / ASC_ISSUER_ID
#                         an App Store Connect API key; when set, it is
#                         passed to xcodebuild so -allowProvisioningUpdates
#                         can create/update provisioning profiles (needed
#                         the first time, and whenever a capability such
#                         as NFC is added) without a signed-in Xcode account.
#
# Note: xcodebuild archive run over an SSH (non-GUI) session can fail
# codesigning with errSecInternalComponent. If that happens, run this
# script from a GUI login session (for example a one-shot LaunchAgent
# in the user's GUI domain) instead of over SSH.
set -euo pipefail
cd "$(dirname "$0")/.."

APP="${APP:-Fathom}"
SCHEME="${SCHEME:-$APP}"
BUNDLE_ID="${BUNDLE_ID:-com.example.fathom}"
: "${OTA_TOKEN:?set OTA_TOKEN}"
: "${OTA_SSH_HOST:?set OTA_SSH_HOST}"
: "${OTA_BASE_URL:?set OTA_BASE_URL}"
: "${OTA_ROOT:?set OTA_ROOT}"
BASE="$OTA_BASE_URL/$OTA_TOKEN"
ROOT="$OTA_ROOT/$OTA_TOKEN"
BUILD="${1:-$(date +%Y%m%d%H%M)}"
NOTES="${2:-}"
MIN_BUILD="${MIN_BUILD:-1}"

EXTRA_ARGS=()
if [ -n "${DEVELOPMENT_TEAM:-}" ]; then EXTRA_ARGS+=("DEVELOPMENT_TEAM=$DEVELOPMENT_TEAM"); fi
if [ -n "${BUNDLE_ID_SETTING:-}" ]; then EXTRA_ARGS+=("PRODUCT_BUNDLE_IDENTIFIER=$BUNDLE_ID_SETTING"); fi
for spec in ${=EXTRA_BUILD_SETTINGS:-}; do EXTRA_ARGS+=("$spec"); done
AUTH_ARGS=()
if [ -n "${ASC_KEY_PATH:-}" ] && [ -n "${ASC_KEY_ID:-}" ] && [ -n "${ASC_ISSUER_ID:-}" ]; then
  AUTH_ARGS+=(-authenticationKeyPath "$ASC_KEY_PATH" -authenticationKeyID "$ASC_KEY_ID" -authenticationKeyIssuerID "$ASC_ISSUER_ID")
fi

echo "==> generate + archive ($APP build $BUILD)"
xcodegen generate >/dev/null
rm -rf "build/$APP.xcarchive"
xcodebuild archive -project "$APP.xcodeproj" -scheme "$SCHEME" \
  -archivePath "build/$APP.xcarchive" -destination 'generic/platform=iOS' \
  CURRENT_PROJECT_VERSION="$BUILD" "${EXTRA_ARGS[@]}" "${AUTH_ARGS[@]}" -allowProvisioningUpdates -quiet

APPDIR="build/$APP.xcarchive/Products/Applications/$APP.app"
VERSION=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$APPDIR/Info.plist")
codesign --verify --deep --strict "$APPDIR"

echo "==> packaging IPA"
rm -rf build/ipa "build/$APP.ipa"
mkdir -p build/ipa/Payload
cp -R "$APPDIR" build/ipa/Payload/
(cd build/ipa && zip -qry "../$APP.ipa" Payload)

echo "==> staging on $OTA_SSH_HOST: $BASE/"
scp -q "build/$APP.ipa" "$OTA_SSH_HOST:/tmp/$APP.ipa"
ssh "$OTA_SSH_HOST" "set -e
sudo -n mkdir -p $ROOT
sudo -n mv /tmp/$APP.ipa $ROOT/$APP.ipa.new && sudo -n mv $ROOT/$APP.ipa.new $ROOT/$APP.ipa && sudo -n chmod 644 $ROOT/$APP.ipa
OTA_APP='$APP' OTA_BUNDLE='$BUNDLE_ID' OTA_BASE='$BASE' OTA_VERSION='$VERSION' OTA_BUILD='$BUILD' OTA_MIN='$MIN_BUILD' OTA_NOTES='$NOTES' OTA_ROOT='$ROOT' sudo -nE python3 - <<'EOF'
import json, os, plistlib, html
app, bundle, base, root = os.environ['OTA_APP'], os.environ['OTA_BUNDLE'], os.environ['OTA_BASE'], os.environ['OTA_ROOT']
version, build, min_build, notes = os.environ['OTA_VERSION'], int(os.environ['OTA_BUILD']), int(os.environ['OTA_MIN']), os.environ['OTA_NOTES']
install = f'itms-services://?action=download-manifest&url={base}/manifest.plist'
with open(f'{root}/manifest.plist', 'wb') as f:
    plistlib.dump({'items': [{'assets': [{'kind': 'software-package', 'url': f'{base}/{app}.ipa'}],
        'metadata': {'bundle-identifier': bundle, 'bundle-version': version, 'kind': 'software', 'title': app}}]}, f)
with open(f'{root}/version.json', 'w') as f:
    json.dump({'version': version, 'build': build, 'minBuild': min_build, 'installUrl': install, 'notes': notes}, f)
with open(f'{root}/index.html', 'w') as f:
    f.write(f'''<!DOCTYPE html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>Install {html.escape(app)}</title>
<style>body{{background:#04121d;color:#e9e2d0;margin:0;font:16px/1.6 -apple-system,sans-serif}}.wrap{{max-width:520px;margin:0 auto;padding:56px 24px;text-align:center}}h1{{letter-spacing:6px;margin:8px 0 2px}}.sub{{color:#c8a86a}}.btn{{display:inline-block;margin-top:26px;background:#c8a86a;color:#04121d;font-weight:700;padding:14px 30px;text-decoration:none;border-radius:99px}}.mut{{color:#8fa3ad;font-size:14px;margin-top:22px}}</style></head>
<body><div class="wrap"><h1>{html.escape(app.upper())}</h1><div class="sub">version {html.escape(version)} (build {build})</div><p>Private build.</p><a class="btn" href="{install}">Install {html.escape(app)}</a><p class="mut">{html.escape(notes) or 'iOS will ask you to confirm.'}</p></div></body></html>''')
for n in ('manifest.plist', 'version.json', 'index.html'): os.chmod(f'{root}/{n}', 0o644)
print('staged', version, build)
EOF"
echo "==> $BASE/"
