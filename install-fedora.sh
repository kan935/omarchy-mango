#!/bin/bash

# Omarchy on Fedora with MangoWC
#
# Installs the Fedora/Mango fork into the current user's home directory:
#   ~/.local/share/omarchy     program files
#   ~/.config                  desktop configuration
#   /usr/local/share/wayland-sessions/omarchy-mango.desktop
#
# Existing ~/.config files that would be replaced are backed up first.
#
# Usage: ./install-fedora.sh [--skip-packages] [--theme <name>]

set -eEo pipefail

SOURCE_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
OMARCHY_PATH="$HOME/.local/share/omarchy"
CONFIG_DIR="$HOME/.config"
STATE_DIR="$HOME/.local/state/omarchy"
THEME="tokyo-night"
SKIP_PACKAGES=false

log() {
  printf '\n\033[1;34m==>\033[0m %s\n' "$*"
}

warn() {
  printf '\033[1;33mWarning:\033[0m %s\n' "$*" >&2
}

die() {
  printf '\033[1;31mError:\033[0m %s\n' "$*" >&2
  exit 1
}

usage() {
  cat <<EOF
Usage: $0 [options]

Options:
  --skip-packages   Do not install Fedora packages
  --theme <name>    Initial theme (default: tokyo-night)
  -h, --help        Show this help
EOF
}

while (($#)); do
  case "$1" in
  --skip-packages)
    SKIP_PACKAGES=true
    shift
    ;;
  --theme)
    THEME="${2:-}"
    [[ -n $THEME ]] || die "--theme requires a name"
    shift 2
    ;;
  -h | --help)
    usage
    exit 0
    ;;
  *)
    die "Unknown option: $1"
    ;;
  esac
done

[[ -f /etc/fedora-release ]] || die "This installer targets Fedora."

export OMARCHY_PATH
export PATH="$OMARCHY_PATH/bin:$HOME/.local/bin:$PATH"

install_packages() {
  local package_file="$SOURCE_DIR/install/omarchy-fedora.packages"
  local package=""
  local pending=()
  local missing=()

  [[ -f $package_file ]] || die "Missing package list: $package_file"

  # Quickshell is the Quattro desktop shell. Fedora does not carry it in its
  # main repositories, so enable the maintained COPR when it is not installed.
  if ! rpm -q quickshell >/dev/null 2>&1; then
    sudo -v
    # dnf5's copr command lives in dnf5-plugins, which a minimal Fedora
    # installation may not include yet.
    if ! dnf copr --help >/dev/null 2>&1; then
      sudo dnf install -y dnf5-plugins
    fi
    sudo dnf copr enable -y errornointernet/quickshell
  fi

  package_installed() {
    case "$1" in
    ffmpeg-free)
      command -v ffmpeg >/dev/null 2>&1 || rpm -q ffmpeg-free >/dev/null 2>&1
      ;;
    *)
      rpm -q "$1" >/dev/null 2>&1
      ;;
    esac
  }

  while IFS= read -r package; do
    [[ -n $package ]] || continue
    package_installed "$package" || pending+=("$package")
  done < <(grep -vE '^[[:space:]]*(#|$)' "$package_file")

  if ((${#pending[@]} == 0)); then
    log "All Fedora packages are already installed"
    return 0
  fi

  log "Installing ${#pending[@]} Fedora packages (this can take a while)"
  sudo -v
  sudo dnf install -y --skip-unavailable "${pending[@]}" || true

  for package in "${pending[@]}"; do
    package_installed "$package" || missing+=("$package")
  done

  if ((${#missing[@]})); then
    warn "These packages are still missing: ${missing[*]}"
    echo "MangoWC is packaged as 'mangowm' in the Terra repository: https://terra.fyralabs.com/" >&2
    echo "Install the remaining packages manually, then rerun this script." >&2
  fi
}

copy_program_files() {
  log "Installing Omarchy into $OMARCHY_PATH"

  mkdir -p "$OMARCHY_PATH"
  if [[ $SOURCE_DIR == "$OMARCHY_PATH" ]]; then
    log "Already running from $OMARCHY_PATH"
    return 0
  fi

  tar -C "$SOURCE_DIR" --exclude=.git -cf - . | tar -C "$OMARCHY_PATH" -xf -
}

backup_conflicts() {
  local backup_root="$CONFIG_DIR/omarchy-install-backup-$(date +%Y%m%d-%H%M%S)"
  local source="$SOURCE_DIR/config"
  local file=""
  local rel=""
  local target=""
  local backed_up=false

  while IFS= read -r -d '' file; do
    rel="${file#"$source"/}"
    target="$CONFIG_DIR/$rel"
    [[ -e $target || -L $target ]] || continue

    mkdir -p "$backup_root/$(dirname "$rel")"
    cp -a "$target" "$backup_root/$rel"
    backed_up=true
  done < <(find "$source" -type f -print0)

  if $backed_up; then
    log "Backed up replaced configuration to $backup_root"
  fi
}

copy_user_config() {
  log "Installing configuration into $CONFIG_DIR"

  mkdir -p "$CONFIG_DIR"
  backup_conflicts
  cp -a "$SOURCE_DIR/config/." "$CONFIG_DIR/"

  # Keep Walker available for the automatic legacy fallback. The Quattro
  # session stops the service and closes Walker during startup.
  mkdir -p "$CONFIG_DIR/autostart" "$CONFIG_DIR/systemd/user/app-walker@autostart.service.d"
  cp "$SOURCE_DIR/default/walker/walker.desktop" "$CONFIG_DIR/autostart/walker.desktop"
  cp "$SOURCE_DIR/default/walker/restart.conf" \
    "$CONFIG_DIR/systemd/user/app-walker@autostart.service.d/restart.conf"

  mkdir -p "$CONFIG_DIR/elephant/menus"
  local menu=""
  for menu in omarchy_themes omarchy_background_selector omarchy_unlocks; do
    ln -snf "$OMARCHY_PATH/default/elephant/$menu.lua" "$CONFIG_DIR/elephant/menus/$menu.lua"
  done

  if [[ ! -f $HOME/.XCompose ]]; then
    cat >"$HOME/.XCompose" <<'EOF'
include "%H/.local/share/omarchy/default/xcompose"
EOF
  fi

  mkdir -p "$HOME/.local/share/fonts"
  cp -f "$OMARCHY_PATH/config/omarchy.ttf" "$HOME/.local/share/fonts/omarchy.ttf"
  command -v fc-cache >/dev/null 2>&1 && fc-cache -f >/dev/null 2>&1 || true
}

install_lock_auth() {
  log "Configuring lock screen authentication"
  OMARCHY_INSTALL_USER="$USER" "$OMARCHY_PATH/bin/omarchy-apply-lock" ||
    warn "Could not configure lock screen authentication"
}

install_session_file() {
  log "Installing the Omarchy (Mango) Wayland session"
  sudo -v || die "sudo access is required to install the Wayland session file"
  sudo install -Dm644 "$OMARCHY_PATH/default/wayland-sessions/omarchy-mango.desktop" \
    /usr/local/share/wayland-sessions/omarchy-mango.desktop
}

prepare_theme() {
  local current="$CONFIG_DIR/omarchy/current"
  local theme_source="$OMARCHY_PATH/themes/$THEME"
  local background=""

  [[ -d $theme_source ]] || die "Theme '$THEME' does not exist in $OMARCHY_PATH/themes"

  log "Preparing the initial theme: $THEME"

  mkdir -p "$current"
  rm -rf "$current/next-theme"
  mkdir -p "$current/next-theme"
  cp -a "$theme_source/." "$current/next-theme/"

  OMARCHY_PATH="$OMARCHY_PATH" "$OMARCHY_PATH/bin/omarchy-theme-set-templates"

  rm -rf "$current/theme"
  mv "$current/next-theme" "$current/theme"
  printf '%s\n' "$THEME" >"$current/theme.name"

  background=$(find -L "$current/theme/backgrounds" -maxdepth 1 -type f 2>/dev/null | sort | head -n 1 || true)
  if [[ -n $background ]]; then
    ln -nsf "$background" "$current/background"
  fi

  mkdir -p "$CONFIG_DIR/btop/themes" "$CONFIG_DIR/mako"
  ln -snf "$current/theme/btop.theme" "$CONFIG_DIR/btop/themes/current.theme"
  ln -snf "$current/theme/mako.ini" "$CONFIG_DIR/mako/config"
}

mark_migrations_applied() {
  local migration=""

  log "Marking Arch migrations as applied"
  mkdir -p "$STATE_DIR/migrations"
  for migration in "$OMARCHY_PATH"/migrations/*.sh; do
    [[ -f $migration ]] || continue
    touch "$STATE_DIR/migrations/$(basename "$migration")"
  done
}

verify_install() {
  local failed=false
  local command=""

  for command in mango mmsg quickshell qs waybar walker elephant swaylock swayidle grim slurp wf-recorder; do
    if ! command -v "$command" >/dev/null 2>&1; then
      warn "Required command not found: $command"
      failed=true
    fi
  done

  if [[ -x $OMARCHY_PATH/bin/omarchy-mango-session && -x $OMARCHY_PATH/bin/hyprctl ]]; then
    log "Omarchy launchers are executable"
  else
    warn "Omarchy launchers are missing executable bits"
    failed=true
  fi

  log "Validating the Mango configuration"
  if ! mango -c "$CONFIG_DIR/mango/config.conf" -p; then
    warn "Mango reported configuration problems (see above)"
    failed=true
  fi

  $failed && return 1
  return 0
}

if ! $SKIP_PACKAGES; then
  install_packages
fi

copy_program_files
copy_user_config
install_session_file
prepare_theme
install_lock_auth
mark_migrations_applied

cat <<EOF

Omarchy for Mango is installed.

Next steps:
  1. Log out and choose "Omarchy (Mango)" on the login screen.
     From a TTY you can also run:
       exec $OMARCHY_PATH/bin/omarchy-mango-session
  2. Change themes with: omarchy-theme-set "Tokyo Night"
  3. Check key bindings with: omarchy-menu-keybindings
  4. Update later with: omarchy update

Mango limitations are documented in README.md (no mirroring, per-window
opacity, or lid-switch events; best-effort fallbacks are provided).
EOF

if verify_install; then
  log "Installation verified"
else
  warn "Installation finished, but verification found problems"
  exit 1
fi
