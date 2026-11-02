#!/usr/bin/env bash
# Prints the directory this skill was loaded from, plus its domain and how it
# was installed (plugin cache or symlink).
dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
real="$(cd "$dir" && pwd -P)"
echo "path:   $dir"
if [[ "$real" =~ /skills/([^/]+)/[^/]+$ ]]; then
  echo "domain: ${BASH_REMATCH[1]}"
else
  echo "domain: unknown"
fi
if [[ "$dir" == */plugins/cache/* || "$dir" == */plugins/marketplaces/* ]]; then
  echo "plugin: dotskills (loaded from the plugin cache)"
else
  echo "plugin: none (loaded from a symlink or local folder)"
fi
