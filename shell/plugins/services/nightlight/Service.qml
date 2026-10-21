import QtQuick
import Quickshell
import Quickshell.Io
import "NightlightModel.js" as NightlightModel
import qs.Commons

Item {
  id: root

  // Injected by omarchy-shell (the first-party service loader).
  property var shell: null

  readonly property string home: Quickshell.env("HOME")
  readonly property string stateFile: home + "/.local/state/omarchy/toggles/mango/nightlight-on"

  // Keep in sync with bin/omarchy-toggle-nightlight, which sets the same
  // temperatures for callers outside the shell (keybindings, menu, ssh).
  readonly property int nightTemperature: 4000
  readonly property int dayTemperature: 6500

  property bool stateLoaded: false
  property var temperature: null
  readonly property bool enabled: stateLoaded && NightlightModel.isNightlight(temperature)

  property bool hasPendingTemperature: false
  property int pendingTemperature: 0

  function refresh() {
    if (!statusProbe.running) statusProbe.running = true
  }

  function setNightlight(value) {
    applyTemperature(value ? nightTemperature : dayTemperature)
  }

  function toggle() {
    setNightlight(!enabled)
  }

  function applyTemperature(temp) {
    root.temperature = temp
    root.stateLoaded = true

    if (applyProcess.running) {
      root.pendingTemperature = temp
      root.hasPendingTemperature = true
      return
    }

    runApply(temp)
  }

  function runApply(temp) {
    var enabled = Number(temp) < dayTemperature
    applyProcess.command = ["bash", "-c",
      "if " + (enabled ? "true" : "false") + "; then mkdir -p \"$(dirname \"$1\")\" && touch \"$1\"; else rm -f \"$1\"; fi; pkill -9 -x gammastep >/dev/null 2>&1 || true; setsid gammastep -P -O " + Number(temp) + " >/dev/null 2>&1 &",
      "omarchy-nightlight", stateFile]
    applyProcess.running = true
  }

  Process {
    id: statusProbe
    command: ["bash", "-c", "[[ -f $1 ]] && echo 4000 || echo 6500", "omarchy-nightlight", stateFile]
    stdout: SplitParser {
      onRead: function(line) {
        root.temperature = parseInt(String(line), 10)
        root.stateLoaded = true
      }
    }
  }

  Process {
    id: applyProcess
    onExited: function() {
      if (root.hasPendingTemperature) {
        root.hasPendingTemperature = false
        root.runApply(root.pendingTemperature)
        return
      }

      root.refresh()
    }
  }

  FileView {
    path: root.stateFile
    watchChanges: true
    printErrors: false
    onFileChanged: root.refresh()
    onLoaded: root.refresh()
    onLoadFailed: root.refresh()
  }

  Component.onCompleted: refresh()

  ShellIpc {
    target: "nightlight"

    function status(): string {
      return JSON.stringify({ enabled: root.enabled, temperature: root.temperature })
    }

    function refresh(): void {
      root.refresh()
    }

    function enable(): string {
      root.setNightlight(true)
      return "enabled"
    }

    function disable(): string {
      root.setNightlight(false)
      return "disabled"
    }

    function toggle(): string {
      var enabling = !root.enabled
      root.setNightlight(enabling)
      return enabling ? "enabled" : "disabled"
    }
  }
}
