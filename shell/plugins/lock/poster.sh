#!/bin/bash

# One cached frame shared by all lock outputs, including when OWE is paused.
set -euo pipefail

source_path=$1
cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/omarchy/lock-poster"
signature=$(stat -Lc '%s:%y:%z' "$source_path")
key=$(printf '%s\n%s' "$source_path" "$signature" | sha256sum | cut -d ' ' -f 1)
poster="$cache_dir/poster-$key.jpg"
mkdir -p "$cache_dir"
exec {lock_fd}>"$cache_dir/.lock"
flock -w 10 "$lock_fd"

if [[ ! -s $poster ]]; then
  temporary=$(mktemp "$cache_dir/.poster-XXXXXX.jpg")
  trap 'rm -f "$temporary"' EXIT
  if command -v ffmpegthumbnailer >/dev/null 2>&1; then
    timeout -k 1 5 ffmpegthumbnailer -i "$source_path" -o "$temporary" -s 1920 -q 8 {lock_fd}>&-
  else
    timeout -k 1 5 ffmpeg -nostdin -v error -ss 1 -i "$source_path" -frames:v 1 \
      -vf 'scale=1920:1080:force_original_aspect_ratio=increase,crop=1920:1080' -q:v 3 -y "$temporary" {lock_fd}>&-
  fi
  [[ -s $temporary ]]
  mv -f "$temporary" "$poster"
  find "$cache_dir" -maxdepth 1 -type f -name 'poster-*.jpg' ! -name "poster-$key.jpg" -delete
fi

printf '%s\n' "$poster"
