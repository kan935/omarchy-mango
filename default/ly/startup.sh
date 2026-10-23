# This file is executed when starting Ly, before the TTY is taken over.
# It remaps the TTY palette to the active Omarchy theme (slot 0 = background,
# slots 1-15 = the theme color0..15), so Ly's palette colours render themed.
# install-fedora.sh replaces @HOME@ with the installing user's home directory.

tty=/dev/tty1
theme_file="@HOME@/.config/omarchy/current/theme/colors.toml"
[[ -r $theme_file ]] || exit 0

for ((i = 0; i < 16; i++)); do
  if ((i == 0)); then
    key=background
  else
    key=color$i
  fi

  hex=$(sed -n "s/^$key = \"#\([0-9a-fA-F]\{6\}\)\"$/\1/p" "$theme_file" | head -1)
  [[ -n $hex ]] && printf '\033]P%x%s' "$i" "$hex" >"$tty"
done

printf '\033[H\033[2J' >"$tty"
