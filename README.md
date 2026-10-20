# Omarchy for Fedora + MangoWC

This is a fork of [Omarchy 3.8.4](https://github.com/basecamp/omarchy) ported
from Arch Linux + Hyprland to **Fedora 44** + **[MangoWC](https://github.com/mangowm/mango)**.

It keeps Omarchy's themes, menus, CLI, Waybar look, Walker launcher, keybinding
conventions, screenshots, screen recording, idle/lock, and desktop helpers. The
Hyprland-specific pieces are replaced with Mango IPC, Waybar's `ext/workspaces`
module, `swaylock`, `swayidle`, `gammastep`, and `wf-recorder`.

Omarchy 4.x is not used as the base because its desktop shell is a large
Quickshell application built around Hyprland. Omarchy 3.8.4 already provides the
Waybar + Walker desktop that maps cleanly onto Mango.

## Requirements

- Fedora 44
- MangoWC 0.18 or newer (`mangowm` from the [Terra repository](https://terra.fyralabs.com/))
- Waybar 0.15 or newer (Fedora 44 ships 0.15 with `ext/workspaces`)
- A Wayland session manager or display manager (GDM, SDDM, greetd, or a TTY)

Mango is not in Fedora's main repositories. With Terra enabled:

```bash
sudo dnf install mangowm
```

Verify it before installing:

```bash
mango -v
mmsg --help
```

## Install

```bash
git clone <your-fork-url> ~/omarchy-mango
cd ~/omarchy-mango
./install-fedora.sh
```

The installer:

- installs the Fedora package list in `install/omarchy-fedora.packages`
- copies the fork to `~/.local/share/omarchy`
- copies `config/*` to `~/.config`, backing up replaced files to
  `~/.config/omarchy-install-backup-<timestamp>`
- installs `/usr/local/share/wayland-sessions/omarchy-mango.desktop`
- prepares the `tokyo-night` theme, background symlink, Mako config, and btop theme
- marks the Arch-era migrations as already applied
- validates the generated Mango configuration

Useful options:

```bash
./install-fedora.sh --skip-packages
./install-fedora.sh --theme catppuccin
```

The installer does not start Mango or restart your current desktop session.

## Log in

Log out, then choose **Omarchy (Mango)** in your display manager.

From a TTY, start the session directly:

```bash
exec ~/.local/share/omarchy/bin/omarchy-mango-session
```

Mango reads `~/.config/mango/config.conf`. The repository's entry point layers
Omarchy defaults, the generated theme, user overrides, and persistent toggle
snippets in this order:

```text
~/.config/mango/config.conf
├── ~/.local/share/omarchy/default/mango/{envs,looknfeel,input,windows,bindings,autostart}.conf
├── ~/.config/omarchy/current/theme/mango.conf
├── ~/.config/mango/{monitors,input,bindings,looknfeel,autostart}.conf
└── ~/.local/state/omarchy/toggles/mango/*.conf
```

Validate the result at any time:

```bash
mango -c ~/.config/mango/config.conf -p
```

## Key bindings

Mango uses the same `Super`-based layout as Omarchy. The main bindings:

| Binding | Action |
| --- | --- |
| `Super + Return` | Terminal (Alacritty via `xdg-terminal-exec`) |
| `Super + Shift + Return` | Browser |
| `Super + Space` | Walker launcher |
| `Super + Alt + Space` | Omarchy menu |
| `Super + Ctrl + E` | Walker symbols |
| `Super + Ctrl + C` | Capture menu |
| `Super + W` | Close window |
| `Super + T` | Toggle floating |
| `Super + F` | Toggle fullscreen |
| `Super + J` | Toggle dwindle split direction |
| `Super + L` | Toggle Dwindle/Scroller layout |
| `Super + O` | Pop window out as floating/sticky |
| `Super + 1..0` | Switch to tag 1..10 |
| `Super + Shift + 1..0` | Move window to tag 1..10 |
| `Super + Shift + Alt + 1..0` | Move window silently to tag 1..10 |
| `Super + Tab` / `Super + Shift + Tab` | Next/previous tag |
| `Super + Left/Right/Up/Down` | Focus in direction |
| `Super + Shift + arrows` | Swap window in direction |
| `Super + Ctrl + arrows` | Focus next/previous group member |
| `Super + Alt + arrows` | Join group in direction |
| `Super + Alt + Tab` | Focus next group member |
| `Super + S` | Toggle scratchpad |
| `Super + Alt + S` | Move window to scratchpad |
| `Super + Ctrl + L` | Lock |
| `Super + Print` | Colour picker |
| `Print` | Screenshot |
| `Alt + Print` | Screen recording menu |
| `Super + Ctrl + Print` | Extract text from screen |
| `Super + Ctrl + I` | Toggle idle locking |
| `Super + Ctrl + N` | Toggle nightlight |
| `Super + Ctrl + Delete` | Toggle internal display |
| `Super + Ctrl + Alt + Delete` | Mirror internal display (unsupported, explains why) |

`omarchy-menu-keybindings` prints every binding parsed from the Mango config.
Mango has no `unbind`; redefine a modifier + key later in
`~/.config/mango/bindings.conf` to override it.

## What changed from Omarchy 3.8.4

| Omarchy / Hyprland | This fork |
| --- | --- |
| Hyprland | MangoWC (`mango`, `mmsg`) |
| `uwsm` session | `bin/omarchy-mango-session` + small `uwsm`/`uwsm-app` shims |
| `hyprctl` scripts | `bin/hyprctl` compatibility shim backed by Mango IPC |
| `hyprland/workspaces` | Waybar `ext/workspaces` (Mango implements `ext-workspace-v1`) |
| Hyprland layout indicator | `custom/layout` calling `omarchy-waybar-layout` |
| `hyprlock` | `swaylock` with a generated theme file |
| `hypridle` | `swayidle` |
| `hyprsunset` | `gammastep` |
| `hyprpicker` | `slurp` + `grim` + ImageMagick |
| `hyprshot` | `grim` + `slurp` + `satty` |
| `gpu-screen-recorder` | `wf-recorder` |
| `pacman` / `yay` | `dnf` / `rpm`; AUR commands are disabled |
| Arch migrations | pre-marked as applied; Fedora installer is authoritative |

Mango does not support Hyprland's named workspaces, but its native 10 tags map
directly to Omarchy's workspace keys and the Waybar workspace display.

## Fedora notes

- Polkit uses `mate-polkit`, with `lxpolkit` as a fallback, because
  `polkit-gnome` is not packaged.
- `python3-terminaltexteffects` is unavailable; the screensaver falls back to a
  built-in Python animation.
- `uwsm`, `xdg-terminal-exec`, `hypridle`, `hyprlock`, `hyprsunset`, `hyprpicker`,
  and `gpu-screen-recorder` are either absent or replaced. Compatibility shims
  live in `bin/`.
- Optional applications that Fedora does not package (Spotify, Obsidian, Typora,
  LocalSend) can be installed from Flathub or vendor repositories.
- `omarchy update` uses `dnf upgrade` and skips Arch-only keyring/AUR steps.

## Known Mango limitations

These are Mango capabilities, not missing configuration:

- **Monitor mirroring** is not supported. `monitor_rule` can position, scale,
  rotate, and disable outputs, but cannot clone one output onto another. The
  mirror command reports this and exits non-zero.
- **Per-window opacity** is not exposed. The transparency toggle changes the
  global focused/unfocused opacity instead.
- **Per-window scroll factors** are not supported. Set the global
  `trackpad_scroll_factor` in `~/.config/mango/input.conf`.
- **Lid-switch events** are not exposed by Mango. Use the Omarchy menu or
  `Super + Ctrl + Delete` to manage the internal display.
- **Hyprland zoom** has no Mango equivalent.
- **Multiple audio sources in one recording** are not supported by
  `wf-recorder`. When both desktop and microphone audio are requested, desktop
  audio is recorded and a notification explains the limitation.

## Customisation

- Key bindings: `~/.config/mango/bindings.conf`
- Input and trackpad: `~/.config/mango/input.conf`
- Gaps, borders, blur, animations: `~/.config/mango/looknfeel.conf`
- Monitor rules: `~/.config/mango/monitors.conf`
- Extra autostart: `~/.config/mango/autostart.conf`
- Omarchy defaults: `~/.local/share/omarchy/default/mango/`

Apply changes with:

```bash
omarchy restart mango    # mmsg dispatch reload_config
```

`omarchy-theme-set "Tokyo Night"` regenerates `mango.conf`, `swaylock.conf`,
Waybar/Walker colours, and the rest of the themed files.

## Troubleshooting

**Mango rejects the configuration**

```bash
mango -c ~/.config/mango/config.conf -p
```

**Waybar starts but tags are missing**

Waybar must be 0.15 or newer and Mango must expose `ext-workspace-v1` (0.18+
does). Check:

```bash
waybar -v
mmsg get all-tags
```

**Waybar shows no icons**

Install the Nerd Font and Omarchy glyph font:

```bash
sudo dnf install jetbrainsmono-nerd-fonts
cp ~/.local/share/omarchy/config/omarchy.ttf ~/.local/share/fonts/
fc-cache -f
```

**A legacy Hyprland script fails**

Try the shim directly:

```bash
hyprctl monitors -j
hyprctl clients -j
hyprctl activewindow -j
```

Unsupported dispatches are reported and skipped rather than killing a keybinding.

**Screen sharing reports "Compositor supports neither ext_image_copy_capture or wlr_screencopy"**

Mango exposes both protocols. Confirm the running compositor advertises them:

```bash
wayland-info | grep -E 'screencopy|image_copy'
```

`xdg-desktop-portal-wlr` must run with the same `WAYLAND_DISPLAY` and
`XDG_RUNTIME_DIR` as the session, and PipeWire must be running. This error is
expected when testing a headless Mango inside a private `dbus-run-session`:
D-Bus-activated portal services are started by the real systemd user manager
with `/run/user/<uid>`, so they cannot see the private headless compositor. It
does not occur in a normal login.

**The session is not listed at login**

```bash
ls /usr/local/share/wayland-sessions/omarchy-mango.desktop
```

Make sure `/usr/local/share` is in `XDG_DATA_DIRS`; on Fedora it is by default.

## Development

The working branch is `mango-fedora`. Most scripts still accept the original
Omarchy command names; only compositor-specific commands were renamed from
`omarchy-hyprland-*` to `omarchy-mango-*`.

```bash
bin/omarchy commands --check
mango -c config/mango/config.conf -p
```

## License

MIT, same as Omarchy.
