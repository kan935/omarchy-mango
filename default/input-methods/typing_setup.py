"""Native menu selectors for keyboard layouts and active input methods."""

from collections import Counter
import json
import os
from pathlib import Path
import re
import subprocess
import sys

import configure as setup


def config_home():
  return Path(os.environ.get("XDG_CONFIG_HOME") or str(Path.home() / ".config"))


def keyboard_catalog():
  # Read the same choices as the ISO and first-boot form, then convert console
  # keymaps through systemd's mapping, just as localectl does during install.
  choices = ""
  catalog_path = setup.ROOT / "default/input-methods/keyboard-layouts.txt"
  if catalog_path.exists():
    choices = "\n".join(
      line for line in catalog_path.read_text().splitlines()
      if line.strip() and not line.lstrip().startswith("#"))
  mappings = {}
  for line in Path("/usr/share/systemd/kbd-model-map").read_text().splitlines():
    fields = line.split()
    if not fields or fields[0].startswith("#"):
      continue
    layout = fields[1].split(",")[0]
    variant = fields[3].split(",")[0]
    mappings.setdefault(fields[0], layout + (":" + variant if variant != "-" else ""))
  # The console names systemd's table lacks convert as keyboard_xkb_settings in
  # omarchy-provision-owner does, so a choice types what it did at install.
  mappings.update({"bg-cp1251": "bg:phonetic", "colemak": "us:colemak", "cz": "cz:qwerty",
                   "kyrgyz": "kg", "de_CH-latin1": "ch", "no-latin1": "no"})
  catalog = {}
  for choice in choices.splitlines():
    label, keymap, *input_settings = choice.split("|")
    layout = input_settings[1] if len(input_settings) > 1 else mappings.get(keymap, keymap)
    # Composition engines belong in Input Methods, not as duplicate US layouts.
    catalog.setdefault(layout, label)
  return catalog


MANGO_INPUT_KEYS = ("xkb_rules_layout", "xkb_rules_variant", "xkb_rules_options")


def mango_input_values(config_home):
  # Mango's input file keeps the keyboard selection, like Hyprland's input
  # options did. Machine defaults answer for a not-yet-written user file, and
  # its commented examples never win over live values.
  for path in (config_home / "mango/input.conf", setup.ROOT / "default/mango/input.conf"):
    text = setup.read(path)
    signed = setup.values(text)
    if "xkb_rules_layout" in signed:
      return signed
  return {}


def keyboard_selection():
  signed = mango_input_values(config_home())
  layouts = signed.get("xkb_rules_layout", "us").split(",")
  variants = signed.get("xkb_rules_variant", "").split(",")
  return [layout + (":" + variants[index] if index < len(variants) and variants[index] else "")
          for index, layout in enumerate(layouts)]


def picker_rows(catalog, selected):
  # Current entries stay first, in switching order, followed by the catalog.
  keys = list(dict.fromkeys(selected + sorted(catalog, key=lambda key: catalog[key])))
  labels = {key: catalog.get(key, key) for key in keys}
  counts = Counter(labels.values())
  rows = {key: "\t" + labels[key] + (f" ({key})" if counts[labels[key]] > 1 else "") for key in keys}
  return rows


def choose(title, catalog, selected, kind, overrides=None):
  catalog = {**catalog, **{key: catalog.get(key, key) for key in selected}}
  rows = picker_rows(catalog, selected)
  args = ["omarchy-menu-select", title] + list(rows.values())
  on_change = ["/usr/bin/python3", str(setup.ROOT / "default/input-methods/typing_setup.py"), "apply", kind, json.dumps({"catalog": catalog, "overrides": overrides or {}})]
  args += ["--", "--multiple", "--width", "620", "--maxheight", "650", "--on-change", json.dumps(on_change), "--change-key", "typing:" + kind]
  for key in selected:
    args += ["--selected", rows[key][1:]]
  result = subprocess.run(args, text=True, capture_output=True)
  if result.returncode == 1:
    return None
  if result.returncode:
    raise RuntimeError(result.stderr.strip() or "The selection menu could not open")


def input_catalog(items):
  available = {item[0]: item[1] for item in setup.available_methods()}
  catalog = {key: preset["label"] for key, preset in setup.PRESETS.items() if key != "none"}
  for name, layout in items:
    if not name.startswith("keyboard-"):
      catalog.setdefault(name, available.get(name, name))
  return catalog, available


def input_items(items, selected, overrides=None, layout="us"):
  if not any(item[0].startswith("keyboard-") for item in items):
    raise RuntimeError("The current input group has no keyboard input")
  # Retained entries keep their switching order; new engines follow them.
  kept = [item for item in items if item[0].startswith("keyboard-") or item[0] in selected]
  current = dict(items)
  return kept + [[name, (overrides or {}).get(name) or setup.engine_layout(name, layout)]
                 for name in selected if name not in current]


def set_inputs(group, layout, before, after):
  if before == after:
    return
  try:
    # Removing the active engine must return typing to the keyboard.
    setup.run(["fcitx5-remote", "-c"])
    setup.live_set(group, layout, after)
    if setup.live_group() != (group, layout, after):
      raise RuntimeError("Fcitx did not retain the input selection")
  except BaseException:
    setup.live_set(group, layout, before)
    raise


def configure_inputs():
  group, layout, items = setup.live_group()
  catalog, available = input_catalog(items)
  current = [name for name, override in items if not name.startswith("keyboard-")]
  choose("Input Methods", catalog, current, "input", dict(items))


def load_engines(names, catalog):
  packages = sorted({package for name in names for package in setup.PRESETS.get(name, {}).get("packages", [])})
  absent = [package for package in packages
            if subprocess.run(["omarchy-pkg-present", package], capture_output=True).returncode]
  if absent or any(name not in setup.PRESETS for name in names):
    labels = ", ".join(catalog.get(name, name) for name in names)
    raise RuntimeError(f"Install {' '.join(absent) or 'its engine'} to use {labels}")
  # Fcitx discovers engines only at startup, so one installed while it was
  # running (by an update, say) needs a restart before it can be selected.
  setup.run(["omarchy-restart-xcompose"])
  for name in names:
    setup.wait_ready(name)


def save_inputs(selected, overrides=None):
  group, layout, items = setup.live_group()
  catalog, available = input_catalog(items)
  missing = [name for name in selected if name not in available]
  if missing:
    load_engines(missing, catalog)
    group, layout, items = setup.live_group()
  set_inputs(group, layout, items, input_items(items, selected, overrides, layout))
  # Only a saved engine claims the CJK font fallback, and a failed font write
  # returns the group so the menu's restored checks stay true.
  config_home = Path(os.environ.get("XDG_CONFIG_HOME") or str(Path.home() / ".config"))
  try:
    for name in selected:
      if name in setup.PRESETS:
        setup.font_default(config_home, name)
  except BaseException:
    setup.live_set(group, layout, items)
    raise


def add_input(method):
  group, layout, items = setup.live_group()
  current = [name for name, override in items if not name.startswith("keyboard-")]
  if method not in current:
    save_inputs(current + [method])


def seed_language(method):
  # A new CJK language brings its input method only to a group without one,
  # so a Korean typist switching the interface to Japanese keeps Hangul.
  try:
    group, layout, items = setup.live_group()
    if all(name.startswith("keyboard-") for name, override in items):
      save_inputs([method])
  except (OSError, ValueError, KeyError, IndexError, RuntimeError, subprocess.CalledProcessError) as error:
    print(f"Add {setup.PRESETS[method]['label']} under Setup > Typing > Input Methods: {error}", file=sys.stderr)
  config_home = Path(os.environ.get("XDG_CONFIG_HOME") or str(Path.home() / ".config"))
  setup.font_default(config_home, method)


def keyboard_values(selected):
  if not selected:
    raise ValueError("Select at least one keyboard layout")
  parts = [value.split(":", 1) for value in selected]
  # Preserve the installer's Latin-leading rule for desktop keybindings.
  if parts[0][0] in setup.NON_LATIN:
    parts = [["us"]] + [part for part in parts if part != ["us"]]
  layouts = ",".join(part[0] for part in parts)
  variants = ",".join(part[1] if len(part) > 1 else "" for part in parts)
  return layouts, variants


def save_keyboard(selected):
  layouts, variants = keyboard_values(selected)
  path = config_home() / "mango/input.conf"
  original = setup.read(path) if path.exists() else None
  group, old_layout, before = setup.live_group()
  group_changed = False
  try:
    save_mango_input(path, layouts, variants, original)
    expected = [layout + (":" + variant if variant else "")
                for layout, variant in zip(layouts.split(","), variants.split(","))]
    if keyboard_selection() != expected:
      raise RuntimeError("Your personal keyboard layout override takes precedence over this selection")
    first_layout = layouts.split(",")[0]
    first_variant = variants.split(",")[0]
    group_layout = first_layout + ("-" + first_variant if first_variant else "")
    primary = next((item[0] for item in before if item[0].startswith("keyboard-")), None)
    if primary is None:
      raise RuntimeError("The current input group has no keyboard input")
    keyboard = "keyboard-" + group_layout
    # An engine kept on QWERTY for the old layout is re-decided for the new
    # one; an override the user chose stays.
    after = [[keyboard, ""]] + [
      [name, setup.engine_layout(name, group_layout) if override == setup.engine_layout(name, old_layout) else override]
      for name, override in before if name not in (primary, keyboard)]
    group_changed = True
    setup.live_set(group, group_layout, after)
    if setup.live_group() != (group, group_layout, after):
      raise RuntimeError("Fcitx did not retain the keyboard selection")
  except BaseException:
    if original is None:
      path.resolve().unlink(missing_ok=True)
    else:
      setup.atomic_write(path, original)
    if group_changed:
      setup.live_set(group, old_layout, before)
    raise


def save_mango_input(path, layouts, variants, original):
  # Patch the active xkb_rules_* lines in place, whatever else the file
  # carries: Mango's auto reload picks the edit up live, so no compositor
  # restart command is needed. A missing user file starts from the fork
  # defaults so the machine's other input settings stay visible.
  text = (original or setup.read(setup.ROOT / "default/mango/input.conf")).splitlines(keepends=True)
  qualified = ((MANGO_INPUT_KEYS[0], layouts), (MANGO_INPUT_KEYS[1], variants))
  found = set()
  for index, line in enumerate(text):
    for key, value in qualified:
      if re.match(r"^" + key + r"\s*=.*$", line):
        text[index] = f"{key}={value}\n"
        found.add(key)
  options = mango_input_values(config_home()).get(MANGO_INPUT_KEYS[2]) or "compose:caps"
  grp_rules = [rule for rule in options.split(",") if rule.startswith("grp:")]
  if len(layouts.split(",")) > 1 and not grp_rules:
    options += ("" if not options or options.endswith(",") else ",") + "grp:alts_toggle"
  for key, value in [(MANGO_INPUT_KEYS[2], options), *[(key, value) for key, value in qualified if key not in found]]:
    # Keep one options line and append only keys the file lacks entirely.
    for index, line in enumerate(text):
      if re.match(r"^" + key + r"\s*=.*$", line):
        text[index] = f"{key}={value}\n"
        break
    else:
      text.append(f"{key}={value}\n")
  setup.atomic_write(path, "".join(text))
  # Mango watches its config files (auto reload); the explicit dispatch is the
  # belt and braces the fork's other config writers lean on.
  try:
    setup.run(["mmsg", "dispatch", "reload_config"])
  except (OSError, subprocess.CalledProcessError):
    pass


def configure_keyboard():
  current = keyboard_selection()
  catalog = keyboard_catalog()
  choose("Keyboard Layouts", catalog, current, "keyboard")


def apply_selection(kind, context, values):
  catalog = context["catalog"]
  rows = picker_rows(catalog, [])
  valid = {row[1:]: key for key, row in rows.items()}
  if not isinstance(values, list) or any(not isinstance(value, str) or value not in valid for value in values):
    raise ValueError("The menu returned an invalid selection")
  selected = list(dict.fromkeys(valid[value] for value in values))
  if kind == "input":
    save_inputs(selected, context.get("overrides"))
  else:
    save_keyboard(selected)
    selected = keyboard_selection()
  print(json.dumps([rows[key][1:] for key in selected]))


def main():
  if sys.argv[1:2] == ["seed-language"] and len(sys.argv) == 3:
    seed_language(sys.argv[2])
    return
  if sys.argv[1:2] == ["add"] and len(sys.argv) == 3:
    try:
      add_input(sys.argv[2])
    except (OSError, ValueError, RuntimeError, subprocess.CalledProcessError) as error:
      raise SystemExit(f"Input method could not be added: {error}")
    return
  applying = len(sys.argv) == 5 and sys.argv[1] == "apply"
  kind = sys.argv[2] if applying else sys.argv[1] if len(sys.argv) == 2 else ""
  if kind not in ("input", "keyboard"):
    raise ValueError("Choose keyboard or input setup")
  title = "Input methods" if kind == "input" else "Keyboard layouts"
  try:
    if applying:
      apply_selection(kind, json.loads(sys.argv[3]), json.loads(sys.argv[4]))
    elif kind == "input":
      configure_inputs()
    else:
      configure_keyboard()
  except (OSError, ValueError, RuntimeError, subprocess.CalledProcessError) as error:
    subprocess.run(["omarchy-notification-send", title + " could not be updated", str(error)], check=True)
    raise SystemExit(1)


if __name__ == "__main__":
  main()
