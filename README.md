# Omarchy for Fedora + MangoWC

This is a fork of [Omarchy](https://github.com/basecamp/omarchy) for **Fedora 44**
and **[MangoWC](https://github.com/mangowm/mango)**. It keeps Omarchy's themes,
menus, CLI, keybinding conventions, screenshots, recording, idle/lock, and
desktop helpers, while combining them with the Omarchy 4 "Quattro" Quickshell
desktop from the upstream `quattro` channel.

Quattro is the only desktop shell: bar, tags, menus, notifications, OSD,
wallpaper, theme and background pickers, idle/lock screen, and the polkit
agent. The Hyprland-specific Quattro integrations are patched to Mango's
`mmsg` IPC and `wlr-randr`. The Omarchy 3 stack (Waybar, Walker, Mako, swaybg,
swayidle, and SwayOSD) is not installed or started.

## Requirements

- Fedora 44
- MangoWC 0.18.2 or newer (`mangowm` from the [Terra repository](https://terra.fyralabs.com/))
- Quickshell 0.3.2, installed from the Fedora COPR
  [`errornointernet/quickshell`](https://copr.fedorainfracloud.org/coprs/errornointernet/quickshell/)
- A Wayland session manager or display manager (GDM, SDDM, greetd, or a TTY)

Quattro is required for the desktop bar and panels. Mango will start without
it, but there is no secondary Waybar/Walker session.

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
- enables the Quickshell COPR and installs `quickshell` when it is missing
- copies the fork to `~/.local/share/omarchy`, including the Quattro `shell/`
- copies `config/*` to `~/.config`, backing up replaced files to
  `~/.config/omarchy-install-backup-<timestamp>`
- installs `/usr/local/share/wayland-sessions/omarchy-mango.desktop`
- prepares the `tokyo-night` theme, background symlink, Quattro `shell.json`,
  and btop theme
- writes the PAM service used by the Quattro lock screen
- marks the Arch-era migrations as already applied
- validates the generated Mango configuration

Useful options:

```bash
./install-fedora.sh --skip-packages
./install-fedora.sh --theme catppuccin
```

The installer does not start Mango or restart your current desktop session.

## Log in

Log out, then choose **Omarchy (Mango)** in your display manager. Mango starts
and launches Quattro automatically. There is no secondary bar session.

From a TTY, start the session directly:

```bash
exec ~/.local/share/omarchy/bin/omarchy-mango-session
```

Quattro's startup is managed by
`~/.local/share/omarchy/bin/omarchy-mango-session-start`. The shell's log is
written to `$XDG_RUNTIME_DIR/omarchy/shell.log`.

Mango reads `~/.config/mango/config.conf`. The repository's entry point layers
Omarchy defaults, the generated theme, user overrides, and persistent toggle
snippets in this order:

```text
~/.config/mango/config.conf
├── ~/.local/share/omarchy/default/mango/{envs,looknfeel,input,windows,autostart}.conf
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
| `Super + Space` | Omarchy menu (Quattro) |
| `Super + Alt + Space` | Omarchy menu (Quattro) |
| `Super + Ctrl + V` | Clipboard history |
| `Super + Ctrl + E` | Emoji picker |
| `Super + Ctrl + C` | Capture menu |
| `Super + Ctrl + Space` | Background picker |
| `Super + Shift + Ctrl + Space` | Theme picker |
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
Only `~/.config/mango/bindings.conf` is sourced; it begins as a full copy of
`default/mango/bindings.conf`, so edit that user file directly. Mango has no
`unbind`; redefine a modifier + key later in the same file to override it.

## What changed from upstream Omarchy

| Omarchy / Hyprland | This fork |
| --- | --- |
| Hyprland | MangoWC (`mango`, `mmsg`) |
| Quattro Hyprland services | Quattro services patched for Mango tags, monitors, focus, and keyboard layout |
| `uwsm` session | `bin/omarchy-mango-session` + small `uwsm`/`uwsm-app` shims |
| `hyprctl` scripts | `bin/hyprctl` compatibility shim backed by Mango IPC |
| Hyprland workspaces | Native Mango tags 1-10 in the Quattro bar |
| Hyprland monitor focus | Cursor-monitor probe using `mmsg get cursorpos` |
| `hyprlock` | PAM-backed Quattro lock screen; `swaylock` only if shell IPC is unavailable |
| `hypridle` | Quattro idle service |
| `hyprsunset` | `gammastep` |
| `hyprpicker` | `slurp` + `grim` + ImageMagick |
| `hyprshot` | `grim` + `slurp` + `satty` |
| `gpu-screen-recorder` | `wf-recorder` |
| `pacman` / `yay` | `dnf` / `rpm`; AUR commands are disabled |
| Arch migrations | pre-marked as applied; Fedora installer is authoritative |

Mango does not support Hyprland's named workspaces, but its native 10 tags map
directly to Omarchy's workspace keys and the Quattro bar.

## Fedora notes

- Quickshell is not in Fedora's main repositories. The installer enables the
  `errornointernet/quickshell` COPR. To enable it manually:
  `sudo dnf copr enable -y errornointernet/quickshell`
- Polkit uses Quattro's built-in agent. No separate polkit agent package is
  installed, so it cannot race the shell on login.
- `python3-terminaltexteffects` is unavailable; the screensaver falls back to a
  built-in Python animation.
- `uwsm`, `xdg-terminal-exec`, `hypridle`, `hyprlock`, `hyprsunset`, `hyprpicker`,
  and `gpu-screen-recorder` are either absent or replaced. Compatibility shims
  live in `bin/`.
- Optional applications that Fedora does not package (Spotify, Obsidian, Typora,
  LocalSend) can be installed from Flathub or vendor repositories.
- `omarchy update` uses `dnf upgrade` and skips Arch-only keyring/AUR steps.

## Known Mango limitations

These are Mango or Mango-port limitations, not missing keybindings:

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
- **Outside-click dismissal for tray/media popups** relied on a
  Hyprland-only focus grab. The popup still closes from its bar button or
  `Escape`; clicking another application may leave it open.
- **Multiple audio sources in one recording** are not supported by
  `wf-recorder`. When both desktop and microphone audio are requested, desktop
  audio is recorded and a notification explains the limitation.

## Customisation

- Quattro bar position and transparency: `~/.config/omarchy/shell.json`
- Quattro shell: `~/.local/share/omarchy/shell/` and
  `~/.config/omarchy/shell.json`
- Key bindings: `~/.config/mango/bindings.conf`
- Input and trackpad: `~/.config/mango/input.conf`
- Gaps, borders, blur, animations: `~/.config/mango/looknfeel.conf`
- Monitor rules: `~/.config/mango/monitors.conf`
- Extra autostart: `~/.config/mango/autostart.conf`
- Omarchy defaults: `~/.local/share/omarchy/default/mango/`

The Quattro bar can be changed without editing JSON:

```bash
omarchy bar position top
omarchy bar position bottom
omarchy bar transparent true
omarchy bar transparent toggle
```

Apply Mango changes with:

```bash
omarchy restart mango    # mmsg dispatch reload_config
```

`omarchy-theme-set "Tokyo Night"` or the Quattro theme picker regenerates
`mango.conf`, Quattro shell colors, and the rest of the themed files.

## Troubleshooting

**Mango rejects the configuration**

```bash
mango -c ~/.config/mango/config.conf -p
```

**Quattro does not start**

Check that Quickshell and the bundled shell are present:

```bash
rpm -q quickshell
test -f ~/.local/share/omarchy/shell/shell.qml && echo shell-present
omarchy restart shell
```

If Quickshell is missing:

```bash
sudo dnf copr enable -y errornointernet/quickshell
sudo dnf install quickshell
```

Startup errors are appended to `$XDG_RUNTIME_DIR/omarchy/shell.log`. There is
no fallback bar; install Quickshell and restart the session.

**Bar icons or glyphs are missing**

Install the Nerd Font and Font Awesome icon fonts:

```bash
sudo dnf install jetbrainsmono-nerd-fonts fontawesome-fonts-all
fc-cache -f
omarchy restart shell
```

**A Hyprland compatibility script fails**

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
