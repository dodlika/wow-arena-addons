#!/usr/bin/env bash
# Symlinks every addon folder in this repo (Name/Name.toc) into WoW's AddOns folder,
# so updating is just: git pull, then /reload in game.
# Usage: scripts/link-addons.sh "/path/to/World of Warcraft/Interface/AddOns"
#        (or set WOW_ADDONS_DIR)
set -euo pipefail

ADDONS_DIR="${1:-${WOW_ADDONS_DIR:-}}"
if [ -z "$ADDONS_DIR" ]; then
  echo "usage: $0 \"<path to Interface/AddOns>\"   (or set WOW_ADDONS_DIR)" >&2
  exit 1
fi
if [ ! -d "$ADDONS_DIR" ]; then
  echo "not a folder: $ADDONS_DIR" >&2
  exit 1
fi
REPO="$(cd "$(dirname "$0")/.." && pwd)"

for dir in "$REPO"/*/; do
  dir="${dir%/}"
  name="$(basename "$dir")"
  [ -f "$dir/$name.toc" ] || continue                 # only real addon folders
  target="$ADDONS_DIR/$name"
  if [ -L "$target" ]; then
    if [ "$(readlink "$target")" = "$dir" ]; then
      echo "ok      $name (already linked)"
    else
      ln -sfn "$dir" "$target"
      echo "relinked $name"
    fi
  elif [ -e "$target" ]; then
    echo "skipped $name: a normal folder is already there ($target). Move it away and run again." >&2
  else
    ln -s "$dir" "$target"
    echo "linked  $name"
  fi
done
