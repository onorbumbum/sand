#!/bin/zsh
set -euo pipefail

rm -rf "$HOME/workspace" "$HOME/DerivedDataTartProbe"
mkdir -p "$HOME/workspace"
ln -sfn "/Volumes/My Shared Files/rw/TartSymlinkProbe" "$HOME/workspace/TartSymlinkProbe"
ls -l "$HOME/workspace"
printf guest-write > "$HOME/workspace/TartSymlinkProbe/guest-created.txt"

rm -f /tmp/ro-write.err
if printf forbidden > "/Volumes/My Shared Files/ro/guest-should-fail.txt" 2>/tmp/ro-write.err; then
  echo RO_WRITE_UNEXPECTED_SUCCESS
  exit 44
else
  echo RO_WRITE_BLOCKED
  if [[ -s /tmp/ro-write.err ]]; then
    cat /tmp/ro-write.err
  fi
fi

cd "$HOME/workspace/TartSymlinkProbe"
/usr/bin/time -p xcodebuild -scheme TartSymlinkProbe -derivedDataPath "$HOME/DerivedDataTartProbe" -destination 'generic/platform=macOS' build
test -d "$HOME/DerivedDataTartProbe/Build/Products"
echo DERIVED_DATA_OK
PRODUCT=$(find "$HOME/DerivedDataTartProbe/Build/Products" -path '*/TartSymlinkProbe' -type f | head -1)
"$PRODUCT"
