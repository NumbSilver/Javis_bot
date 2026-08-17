#!/bin/zsh
# Register a packaged Jarvis runtime without compiling on the destination Mac.
set -euo pipefail

script_dir=${0:A:h}
repo_dir=${script_dir:h}
label=com.bytedance.jarvis.server
service_target="gui/$UID/$label"
server_bin=$repo_dir/bin/jarvis-server
config_bin=$repo_dir/bin/jarvis-config

for required in \
  "$server_bin" \
  "$config_bin" \
  "$repo_dir/web/dist/index.html" \
  "$repo_dir/conf/config.yaml"; do
  if [[ ! -e $required ]]; then
    print -u2 "packaged runtime is incomplete: $required"
    exit 1
  fi
done

mkdir -p "$repo_dir/var/log"
chmod 0755 "$server_bin" "$config_bin"

# Preserve the build machine's package signature. A distributed binary must
# never require the destination user to own or authorize a signing private key.
signature_info=$(codesign -dv --verbose=4 "$server_bin" 2>&1)
packaged_authority=$(printf '%s\n' "$signature_info" | sed -n 's/^Authority=//p' | head -1)
if [[ -z $packaged_authority ]]; then
  print -u2 "packaged jarvis-server has no signing authority"
  exit 1
fi
JARVIS_CODESIGN_IDENTITY="$packaged_authority" \
  "$script_dir/verify-server-signature.sh" "$server_bin"

agent_plist=$("$script_dir/render-launchd-plist.sh" "$label")
if launchctl print "$service_target" >/dev/null 2>&1; then
  print -u2 "refusing to replace an already loaded $label service"
  exit 1
fi
launchctl bootstrap "gui/$UID" "$agent_plist"

for attempt in {1..15}; do
  if curl --fail --silent --show-error --max-time 2 \
    -o /dev/null http://127.0.0.1:18800/healthz; then
    launchctl print "$service_target"
    exit 0
  fi
  sleep 1
done

print -u2 "Jarvis did not become healthy within 15 seconds"
print -u2 "inspect $repo_dir/var/log/jarvis-server.error.log"
exit 1
