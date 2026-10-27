#!/usr/bin/env bash
# Completes a partially-uploaded repository.
#  1. Downloads upstream Flycast at the exact commit this fork is based on and copies in every file
#     the repository is missing (existing files are never overwritten).
#  2. Copies ./dark-overlay over the tree: these are the "Flycast Dark" modified files.
set -euo pipefail
SHA="${FLYCAST_BASE_SHA:-e88b0ced2243de137bcccac0072f0c1dd00d41bd}"
URL="${FLYCAST_TARBALL_URL:-https://codeload.github.com/flyinghead/flycast/tar.gz/$SHA}"
WS="${1:-${GITHUB_WORKSPACE:-$(pwd)}}"
cd "$WS"
tmp=$(mktemp -d)
echo "Downloading upstream Flycast: $URL"
curl -fsSL --retry 3 "$URL" -o "$tmp/up.tgz"
mkdir "$tmp/up"
tar -xzf "$tmp/up.tgz" -C "$tmp/up" --strip-components=1
echo "Upstream files: $(find "$tmp/up" -type f | wc -l)"
(cd "$tmp/up" && tar -cf - .) | tar -xf - --skip-old-files -C "$WS"
if [ -d dark-overlay ]; then
  echo "Applying dark-overlay ($(find dark-overlay -type f | wc -l) files)"
  (cd dark-overlay && tar -cf - .) | tar -xf - -C "$WS"
fi
# Sanity check: the Flycast Dark changes must be present (from the overlay or already in the tree)
if ! grep -q fastForwardPace core/hw/pvr/spg.cpp 2>/dev/null; then
  echo "::error::Flycast Dark changes not found. Upload the dark-overlay/ folder to the repository root."
  exit 1
fi
rm -rf "$tmp"
echo "Workspace now has $(find . -type f -not -path './.git/*' | wc -l) files"
