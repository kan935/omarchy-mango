#!/bin/bash

# Captures the current clipboard as a JSON entry on stdout. In watch mode,
# wl-paste invokes this with the payload on stdin and the mime as $1. Without
# arguments, it snapshots the current selection itself.

set -o pipefail

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/omarchy"
IMAGE_DIR="$STATE_DIR/clipboard-images"
mkdir -p "$IMAGE_DIR"

types=$(timeout 2s wl-paste --list-types 2>/dev/null || true)

if [[ ${CLIPBOARD_STATE:-} == "sensitive" ]] || grep -qx 'x-kde-passwordManagerHint' <<<"$types"; then
  exit 0
fi

tmp=
trap 'rm -f -- "$tmp" ${tmp:+"$tmp.utf8"}' EXIT

# The clipboard owner streams the copy and can stall without closing its end, so
# every read is bounded, and a copy cut off at the deadline is dropped, not kept.
read_copy() {
  timeout 2s "$@" >"$tmp" 2>/dev/null && [[ -s $tmp ]]
}

emit_image() {
  local mime="$1"
  local ext hash file
  shift

  ext=${mime#image/}
  [[ $ext == jpeg ]] && ext=jpg

  tmp=$(mktemp --tmpdir="$IMAGE_DIR" clipboard.XXXXXX) || return 0
  read_copy "$@" || return

  hash=$(sha256sum "$tmp" | awk '{print $1}')
  file="$IMAGE_DIR/$hash.$ext"
  if [[ -e $file ]]; then
    rm -f "$tmp"
  else
    mv "$tmp" "$file"
  fi

  jq -cn --arg mime "$mime" --arg path "$file" --arg captured_at "$(LC_TIME="$(omarchy-language locale 2>/dev/null)" date +'%A %H:%M')" \
    '{type:"image", mime:$mime, path:$path, capturedAt:$captured_at}'
}

emit_text() {
  tmp=$(mktemp --tmpdir="$STATE_DIR" clipboard.XXXXXX) || return 0
  read_copy "$@" || return

  # BOM-marked UTF-16 is the one non-UTF-8 text form clients still put on the
  # clipboard; iconv drops the BOM when it converts.
  local bom text_file="$tmp"
  bom=$(od -An -tx1 -N2 "$tmp" | tr -d ' \n')
  if [[ $bom == "fffe" || $bom == "feff" ]]; then
    text_file="$tmp.utf8"
    iconv -f UTF-16 -t UTF-8 "$tmp" >"$text_file" 2>/dev/null || text_file="$tmp"
  fi

  # The watcher reads this stream line by line, so the JSON must stay compact.
  # shortcut: BOM-less UTF-16 is read as UTF-8; Linux clipboards are UTF-8.
  jq -Rsc '{type:"text", text:.}' <"$text_file"
}

case "${1:-}" in
text) emit_text cat; exit 0 ;;
image/*) emit_image "$1" cat; exit 0 ;;
esac

for mime in image/png image/jpeg image/webp image/gif image/bmp image/tiff; do
  if grep -qx "$mime" <<<"$types"; then
    emit_image "$mime" wl-paste --type "$mime"
    exit 0
  fi
done

if grep -q '^text/' <<<"$types" || grep -qx 'UTF8_STRING' <<<"$types" || grep -qx 'STRING' <<<"$types"; then
  emit_text wl-paste --type text --no-newline
fi
