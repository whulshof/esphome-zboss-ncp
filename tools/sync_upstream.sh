#!/usr/bin/env bash
# Follow tostmann/esp-coordinator: copy its firmware onto the 'upstream'
# branch (a vendor branch holding only upstream's files, in this repo's
# layout) and merge that into the current branch. Git then carries
# upstream's changes over our '// esphome:' edits; only lines both sides
# touched conflict.
#
# usage: tools/sync_upstream.sh [branch] [--no-merge]
#   branch     upstream branch to follow (default: wifi-coex; it has the TCP
#              server; tostmann syncs master into it)
#   --no-merge only update the 'upstream' branch
set -euo pipefail

BRANCH=wifi-coex
MERGE=1
for arg in "$@"; do
  case "$arg" in
    --no-merge) MERGE=0 ;;
    -*) echo "unknown option $arg" >&2; exit 2 ;;
    *) BRANCH=$arg ;;
  esac
done
REPO_URL=https://github.com/tostmann/esp-coordinator.git
IDF=components/zboss_ncp/zboss_ncp_idf

# Upstream files this repo does not use: ESPHome provides network,
# provisioning and the info page; the build files are our own.
EXCLUDES=(CMakeLists.txt idf_component.yml version.h.in Kconfig.projbuild '*.png'
          'improv_provisioning.*' 'web_info.*' wifi_coex.cpp netcfg.cpp)

ROOT=$(git rev-parse --show-toplevel)
cd "$ROOT"
if [ -n "$(git status --porcelain)" ]; then
  echo "Working tree not clean; commit or stash first." >&2
  exit 1
fi

TMP=$(mktemp -d)
cleanup() { git worktree remove --force "$TMP/wt" >/dev/null 2>&1 || true; rm -rf "$TMP"; }
trap cleanup EXIT

echo "Fetching tostmann/esp-coordinator ($BRANCH)..."
git clone -q --depth 1 --branch "$BRANCH" "$REPO_URL" "$TMP/src"
SHA=$(git -C "$TMP/src" rev-parse --short=7 HEAD)
VER=$(tr -d '[:space:]' < "$TMP/src/version.txt" 2>/dev/null || echo "?")
SUBJECT=$(git -C "$TMP/src" log -1 --format=%s)

git worktree add -q "$TMP/wt" upstream
DEST="$TMP/wt/$IDF"
rsync_args=(-a --delete)
for e in "${EXCLUDES[@]}"; do rsync_args+=(--exclude "$e"); done
rsync "${rsync_args[@]}" "$TMP/src/main/" "$DEST/src/"
cp "$TMP/src/main/Kconfig.projbuild" "$DEST/Kconfig.projbuild"
cp "$TMP/src/LICENSE" "$DEST/LICENSE.upstream"

cd "$TMP/wt"
git add -A
if git diff --cached --quiet; then
  echo "Upstream branch already at $BRANCH $SHA (v$VER); nothing new."
else
  git diff --cached --stat | tail -1
  git commit -q -m "Upstream: tostmann/esp-coordinator $BRANCH $SHA (v$VER)

$SUBJECT"
  echo "Upstream branch now at $BRANCH $SHA (v$VER)."
fi
cd "$ROOT"

# Things the merge cannot carry: our build files mirror upstream's.
echo
echo "Upstream library versions (compare with $IDF/idf_component.yml):"
grep -E 'esp-z(igbee|boss)-lib' "$TMP/src/main/idf_component.yml" | sed 's/^/  /'
echo "Upstream version: $VER  (ours: $(grep FW_VERSION_STRING "$IDF/src/version.h" | cut -d'"' -f2); update $IDF/src/version.h)"
new_files=$(git diff --name-only --diff-filter=A "upstream@{1}" upstream 2>/dev/null || true)
if [ -n "$new_files" ]; then
  echo "Files upstream added (check they need nothing this repo dropped):"
  echo "$new_files" | sed 's/^/  /'
fi

if [ "$MERGE" = 1 ]; then
  echo
  if git merge --no-edit -m "Merge upstream $BRANCH $SHA (v$VER)" upstream; then
    echo "Merged. Build to check: esphome compile example/zigbee-coordinator.yaml"
  else
    echo "Merge has conflicts (lines both sides changed). Resolve, keep the"
    echo "'// esphome:' intent, then: git commit"
    exit 1
  fi
fi
