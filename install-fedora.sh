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
  --skip-packages   Do not configure repositories or install Fedora packages
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

set_dnf_option() {
  local key="$1"
  local value="$2"
  local conf="$3"

  if grep -qE "^[[:space:]]*$key[[:space:]]*=" "$conf"; then
    sudo sed -i -E "s|^[[:space:]]*$key[[:space:]]*=.*|$key=$value|" "$conf"
  else
    echo "$key=$value" | sudo tee -a "$conf" >/dev/null
  fi
}

configure_dnf() {
  local conf="/etc/dnf/dnf.conf"

  [[ -f $conf ]] || die "Missing $conf; this installer expects a stock Fedora dnf.conf."

  log "Configuring dnf: default yes, fastest mirror, parallel downloads"
  sudo -v || die "sudo access is required to configure dnf"

  set_dnf_option defaultyes True "$conf"
  set_dnf_option fastestmirror True "$conf"
  set_dnf_option max_parallel_downloads 10 "$conf"
}

configure_repos() {
  local releasever=""
  local project=""

  releasever="$(rpm -E %fedora)"
  sudo -v || die "sudo access is required to enable package repositories"

  log "Enabling RPM Fusion, Terra, and the extra COPRs"

  rpm -q rpmfusion-free-release >/dev/null 2>&1 ||
    sudo dnf install -y "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$releasever.noarch.rpm"
  rpm -q rpmfusion-nonfree-release >/dev/null 2>&1 ||
    sudo dnf install -y "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$releasever.noarch.rpm"

  # Terra carries mangowm. Its release package is unsigned, so dnf needs
  # --nogpgcheck for this one install.
  rpm -q terra-release >/dev/null 2>&1 ||
    sudo dnf install -y --nogpgcheck --repofrompath "terra,https://repos.fyralabs.com/terra$releasever" terra-release

  # dnf5's copr command lives in dnf5-plugins, which a minimal Fedora
  # installation may not include yet.
  dnf copr --help >/dev/null 2>&1 || sudo dnf install -y dnf5-plugins
  for project in errornointernet/quickshell imput/helium peterwu/rendezvous; do
    sudo dnf copr enable -y "$project" >/dev/null
  done

  # Stremio beta, packaged by harborstremio and hosted on Cloudsmith.
  if [[ ! -f /etc/yum.repos.d/harborstremio-harbor-beta.repo ]]; then
    sudo tee /etc/yum.repos.d/harborstremio-harbor-beta.repo >/dev/null <<EOF
[harborstremio-harbor-beta]
name=harborstremio-harbor-beta
baseurl=https://dl.cloudsmith.io/public/harborstremio/harbor-beta/rpm/fedora/$releasever/\$basearch
repo_gpgcheck=1
enabled=1
skip_if_unavailable=1
gpgkey=https://dl.cloudsmith.io/public/harborstremio/harbor-beta/gpg.DBAA4A70AAEC7957.key
gpgcheck=1
sslverify=1
metadata_expire=300
type=rpm-md

[harborstremio-harbor-beta-noarch]
name=harborstremio-harbor-beta-noarch
baseurl=https://dl.cloudsmith.io/public/harborstremio/harbor-beta/rpm/fedora/$releasever/noarch
repo_gpgcheck=1
enabled=1
skip_if_unavailable=1
gpgkey=https://dl.cloudsmith.io/public/harborstremio/harbor-beta/gpg.DBAA4A70AAEC7957.key
gpgcheck=1
sslverify=1
metadata_expire=300
type=rpm-md
EOF
  fi
}

install_packages() {
  local package_file="$SOURCE_DIR/install/omarchy-fedora.packages"
  local package=""
  local pending=()
  local missing=()

  [[ -f $package_file ]] || die "Missing package list: $package_file"

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

install_browser_policy_dir() {
  log "Preparing Chromium and Helium theme policy directory"
  sudo -v || die "sudo access is required to create the browser policy directory"
  sudo mkdir -p /etc/chromium/policies/managed
  sudo chmod a+rw /etc/chromium/policies/managed
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

  mkdir -p "$CONFIG_DIR/btop/themes"
  ln -snf "$current/theme/btop.theme" "$CONFIG_DIR/btop/themes/current.theme"

  PATH="$OMARCHY_PATH/bin:$PATH" OMARCHY_PATH="$OMARCHY_PATH" "$OMARCHY_PATH/bin/omarchy-theme-set-gnome" ||
    warn "Could not apply the GTK theme"
  PATH="$OMARCHY_PATH/bin:$PATH" OMARCHY_PATH="$OMARCHY_PATH" "$OMARCHY_PATH/bin/omarchy-theme-set-qt" ||
    warn "Could not apply the Qt theme"
  PATH="$OMARCHY_PATH/bin:$PATH" OMARCHY_PATH="$OMARCHY_PATH" "$OMARCHY_PATH/bin/omarchy-theme-set-neovim" ||
    warn "Could not apply the Neovim theme"
  PATH="$OMARCHY_PATH/bin:$PATH" OMARCHY_PATH="$OMARCHY_PATH" "$OMARCHY_PATH/bin/omarchy-theme-set-browser" ||
    warn "Could not apply the browser theme"
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

  for command in mango mmsg quickshell qs swaylock grim slurp wf-recorder; do
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
  configure_dnf
  configure_repos
  install_packages
fi

copy_program_files
copy_user_config
install_session_file
install_browser_policy_dir
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
