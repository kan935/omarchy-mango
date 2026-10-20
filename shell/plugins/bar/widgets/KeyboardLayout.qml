import QtQuick
import Quickshell
import Quickshell.Io
import qs.Ui
import qs.Commons
import "KeyboardLayoutModel.js" as KeyboardLayoutModel

BarWidget {
  id: root
  moduleName: "omarchy.keyboard-layout"

  property string layoutFull: ""
  property bool multipleLayouts: false
  property var layoutBriefs: ({})
  readonly property string layoutLabel: KeyboardLayoutModel.shortLabel(layoutFull, layoutBriefs)

  function readLayout(line) {
    try {
      var layout = JSON.parse(String(line || "")).layout
      if (typeof layout === "string") root.layoutFull = layout
    } catch (error) {
    }
  }

  function cycleLayout() {
    if (!root.bar || !root.layoutFull) return
    root.bar.run("mmsg dispatch switch_layout")
  }

  Component.onCompleted: {
    briefsProc.running = true
    layoutsProc.running = true
  }

  visible: multipleLayouts && layoutLabel !== ""
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.layoutLabel
    fontSize: Style.font.caption
    horizontalMargin: 6
    tooltipText: root.layoutFull
    onPressed: function() { root.cycleLayout() }
  }

  Process {
    id: watchProc
    command: ["mmsg", "watch", "keyboardlayout"]
    running: true
    stdout: SplitParser { onRead: function(line) { root.readLayout(line) } }
    onExited: watchRestart.start()
  }

  Timer {
    id: watchRestart
    interval: 1000
    onTriggered: watchProc.running = true
  }

  Process {
    id: layoutsProc
    command: ["bash", "-c", "layouts=$(for f in \"$HOME/.config/mango/input.conf\" \"$OMARCHY_PATH/default/mango/input.conf\" /etc/mango/config.conf; do [[ -f $f ]] && sed -n 's/^[[:space:]]*xkb_rules_layout[[:space:]]*=[[:space:]]*//p' \"$f\"; done | tail -n 1); [[ $layouts == *,* ]] && echo yes || echo no"]
    stdout: SplitParser { onRead: function(line) { root.multipleLayouts = String(line).trim() === "yes" } }
  }

  Process {
    id: briefsProc
    command: ["xkbcli", "list", "--load-exotic"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.layoutBriefs = KeyboardLayoutModel.layoutBriefs(text)
    }
  }
}
