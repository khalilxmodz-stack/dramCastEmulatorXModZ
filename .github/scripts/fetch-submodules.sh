#!/usr/bin/env bash
# Populates empty git-submodule directories when the repository was created from a source archive
# (GitHub ZIP downloads contain no submodule contents and no gitlinks). Each dependency is fetched
# at the exact commit pinned by the upstream Flycast commit the archive was taken from.
set -euo pipefail
ROOT="${1:-.}"
BASE_SHA="${FLYCAST_BASE_SHA:-e88b0ced2243de137bcccac0072f0c1dd00d41bd}"
cd "$ROOT"
[ -f .gitmodules ] || { echo "No .gitmodules in $(pwd); nothing to fetch"; exit 0; }

curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
  "https://api.github.com/repos/flyinghead/flycast/git/trees/${BASE_SHA}?recursive=1" -o /tmp/tree.json
python3 - > /tmp/pins.txt <<'PY'
import json, sys
t = json.load(open('/tmp/tree.json'))
if t.get('truncated'):
    sys.exit('upstream tree listing truncated')
for e in t['tree']:
    if e['mode'] == '160000':      # gitlink = submodule pin
        print(e['path'], e['sha'])
PY

git config -f .gitmodules --get-regexp '^submodule\..*\.path$' | while read -r key path; do
  name=${key#submodule.}; name=${name%.path}
  url=$(git config -f .gitmodules --get "submodule.$name.url")
  if [ -n "$(ls -A "$path" 2>/dev/null)" ]; then
    echo "skip $path (already populated)"; continue
  fi
  sha=$(awk -v p="$path" '$1==p {print $2}' /tmp/pins.txt)
  [ -n "$sha" ] || { echo "::error::no pinned commit found for $path"; exit 1; }
  echo "fetch $path @ $sha from $url"
  rm -rf "$path"; mkdir -p "$path"
  git -C "$path" init -q
  git -C "$path" remote add origin "$url"
  git -C "$path" fetch -q --depth 1 origin "$sha" || git -C "$path" fetch -q origin
  git -C "$path" checkout -q "$sha"
  # nested submodules of the dependency, if any (best effort)
  git -C "$path" submodule update --init --recursive --depth 1 || true
done
echo "Submodule population finished"
