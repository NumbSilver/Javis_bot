#!/bin/zsh
set -euo pipefail

script_dir=${0:A:h}
repo_dir=${script_dir:h:h}
build_dir=${JARVIS_PACKAGE_BUILD_DIR:-$repo_dir/build/macos}
dist_dir=${JARVIS_PACKAGE_DIST_DIR:-$repo_dir/dist}
version=${JARVIS_VERSION:-$(git -C "$repo_dir" describe --tags --always --dirty 2>/dev/null || print "0.1.0")}
build_number=${JARVIS_BUILD_NUMBER:-$(date +%Y%m%d%H%M)}
sign_identity=${JARVIS_APP_SIGN_IDENTITY:-Jarvis Local}
timestamp_args=(--timestamp=none)
if [[ "$sign_identity" == "Developer ID Application:"* ]]; then
  timestamp_args=(--timestamp)
fi
app="$build_dir/Jarvis.app"
contents="$app/Contents"
resources="$contents/Resources"
runtime="$resources/runtime"
dmg_root="$build_dir/dmg"
dmg="$dist_dir/Jarvis-$version-arm64.dmg"

fail() {
  print -u2 "build-dmg: $*"
  exit 1
}

for command_name in go npm clang codesign security hdiutil plutil rsync jq; do
  command -v "$command_name" >/dev/null 2>&1 || fail "missing build command: $command_name"
done
[[ "$(uname -s)" == "Darwin" && "$(uname -m)" == "arm64" ]] ||
  fail "the MVP package currently builds only on macOS arm64"
security find-identity -v -p codesigning | grep -F "\"$sign_identity\"" >/dev/null ||
  fail "codesigning identity not found: $sign_identity"

print "==> Building web assets"
npm --prefix "$repo_dir/web" ci
npm --prefix "$repo_dir/web" run build

print "==> Creating runtime payload"
rm -rf "$build_dir"
mkdir -p "$runtime" "$contents/MacOS" "$dist_dir"
rsync -a \
  --exclude '/.git/' \
  --exclude '/.DS_Store' \
  --exclude '/bin/' \
  --exclude '/build/' \
  --exclude '/data/' \
  --exclude '/dist/' \
  --exclude '/packaging/' \
  --exclude '/runs/' \
  --exclude '/var/' \
  --exclude '/web/dist/' \
  --exclude '/web/node_modules/' \
  --exclude '/conf/config.runtime.yaml' \
  --exclude '/*.png' \
  "$repo_dir/" "$runtime/"
mkdir -p "$runtime/bin" "$runtime/web"
ditto "$repo_dir/web/dist" "$runtime/web/dist"

chmod 0600 "$runtime/conf/config.yaml"

print "==> Building packaged binaries"
(
  cd "$repo_dir"
  GOSUMDB=${GOSUMDB:-sum.golang.org} go build -o "$runtime/bin/jarvis-server" ./cmd/jarvis-server
  GOSUMDB=${GOSUMDB:-sum.golang.org} go build -o "$runtime/bin/jarvis-config" ./cmd/jarvis-config
  ./scripts/install-cc-connect.sh
)
cp "$repo_dir/bin/cc-connect-jarvis" "$runtime/bin/cc-connect-jarvis"
cp "$(command -v jq)" "$runtime/bin/jq"
chmod 0755 "$runtime/bin/jarvis-server" "$runtime/bin/jarvis-config" "$runtime/bin/cc-connect-jarvis" "$runtime/bin/jq"

node_bin=$(command -v node)
node_prefix=${node_bin:h:h}
[[ -d "$node_prefix/lib/node_modules/npm" ]] ||
  fail "cannot locate npm beside node at $node_prefix"
mkdir -p "$runtime/toolchain/node/bin" "$runtime/toolchain/node/lib/node_modules"
cp "$node_bin" "$runtime/toolchain/node/bin/node"
ditto "$node_prefix/lib/node_modules/npm" "$runtime/toolchain/node/lib/node_modules/npm"
ln -s ../lib/node_modules/npm/bin/npm-cli.js "$runtime/toolchain/node/bin/npm"
ln -s ../lib/node_modules/npm/bin/npx-cli.js "$runtime/toolchain/node/bin/npx"

print "==> Building native installer app"
MACOSX_DEPLOYMENT_TARGET=13.0 clang \
  -O2 \
  -fobjc-arc \
  -framework Cocoa \
  "$script_dir/JarvisInstaller.m" \
  -o "$contents/MacOS/Jarvis"
sed \
  -e "s|__JARVIS_VERSION__|$version|g" \
  -e "s|__JARVIS_BUILD__|$build_number|g" \
  "$script_dir/Info.plist" >"$contents/Info.plist"
plutil -lint "$contents/Info.plist" >/dev/null
cp "$script_dir/jarvis-mvp" "$resources/jarvis-mvp"
chmod 0755 "$resources/jarvis-mvp"

print "==> Signing app payload with $sign_identity"
for executable in \
  "$runtime/bin/jarvis-server" \
  "$runtime/bin/jarvis-config" \
  "$runtime/bin/cc-connect-jarvis" \
  "$runtime/bin/jq" \
  "$runtime/toolchain/node/bin/node"; do
  codesign --force --options runtime "${timestamp_args[@]}" --sign "$sign_identity" "$executable"
done
codesign \
  --force \
  --options runtime \
  "${timestamp_args[@]}" \
  --sign "$sign_identity" \
  --identifier com.bytedance.jarvis.installer \
  --entitlements "$script_dir/Jarvis.entitlements" \
  "$app"
codesign --verify --deep --strict --verbose=2 "$app"

print "==> Creating signed DMG"
rm -rf "$dmg_root" "$dmg"
mkdir -p "$dmg_root"
ditto "$app" "$dmg_root/Jarvis.app"
ln -s /Applications "$dmg_root/Applications"
hdiutil create \
  -volname "Jarvis $version" \
  -srcfolder "$dmg_root" \
  -format UDZO \
  -ov \
  "$dmg"
codesign --force "${timestamp_args[@]}" --sign "$sign_identity" "$dmg"
codesign --verify --verbose=2 "$dmg"
shasum -a 256 "$dmg" >"$dmg.sha256"

if [[ -n "${JARVIS_NOTARY_PROFILE:-}" ]]; then
  command -v xcrun >/dev/null 2>&1 || fail "xcrun is required for notarization"
  xcrun notarytool submit "$dmg" --keychain-profile "$JARVIS_NOTARY_PROFILE" --wait
  xcrun stapler staple "$dmg"
fi

print
print "DMG ready: $dmg"
print "SHA-256:   $dmg.sha256"
if [[ "$sign_identity" == "Jarvis Local" ]]; then
  print -u2 "warning: Jarvis Local is suitable for MVP testing only."
  print -u2 "Set JARVIS_APP_SIGN_IDENTITY to a Developer ID Application identity for distribution."
fi
