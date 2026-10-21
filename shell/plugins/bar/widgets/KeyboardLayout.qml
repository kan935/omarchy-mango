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
  property bool layoutsRead: false
  property bool briefsRequested: false
  readonly property var inputState: InputMethodState.state
  readonly property bool multipleInputs: (inputState.methods || []).length > 1
  readonly property string layoutLabel: KeyboardLayoutModel.shortLabel(layoutFull, layoutBriefs)
  readonly property string inputLabel: KeyboardLayoutModel.inputLabel(inputState, layoutLabel)
  readonly property bool needsBriefs: layoutsRead && (multipleLayouts || multipleInputs)
  onNeedsBriefsChanged: loadBriefs()

  function readLayout(line) {
    try {
      var layout = JSON.parse(String(line || "")).layout
      if (typeof layout === "string") {
        root.layoutFull = layout
        root.layoutsRead = true
      }
    } catch (error) {
    }
  }

  function loadBriefs() {
    if (!needsBriefs || briefsRequested) return
    briefsRequested = true
    briefsProc.running = true
  }

  function cycleLayout() {
    if (!root.bar) return
    root.bar.run("mmsg dispatch switch_layout")
  }

  Component.onCompleted: {
    layoutsProc.running = true
    watchProc.running = true
  }

  Process {
    id: watchProc
    command: ["mmsg", "watch", "keyboardlayout"]
    stdout: SplitParser { onRead: function(line) { root.readLayout(line) } }
    onExited: watchRestart.start()
  }

  Timer {
    id: watchRestart
    interval: 1000
    onTriggered: watchProc.running = true
  }

  // Mango has no keyboard-device list, so the xkb layout list in the config
  // decides whether there is more than one layout to switch between.
  Process {
    id: layoutsProc
    command: ["bash", "-c", "for f in \"$HOME/.config/mango/input.conf\" \"$OMARCHY_PATH/default/mango/input.conf\" /etc/mango/config.conf; do [[ -f $f ]] && sed -n 's/^[[:space:]]*xkb_rules_layout[[:space:]]*=[[:space:]]*//p' \"$f\"; done | tail -n 1"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.multipleLayouts = String(text || "").indexOf(",") !== -1
    }
  }

  Process {
    id: briefsProc
    command: ["xkbcli", "list", "--load-exotic"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.layoutBriefs = KeyboardLayoutModel.layoutBriefs(text)
    }
  }

  // Mango has no per-device layout list, so keep the current layout visible
  // even when the user has only one configured layout.
  visible: inputLabel !== ""
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.inputLabel
    fontSize: Style.font.caption
    horizontalMargin: 6
    tooltipText: KeyboardLayoutModel.inputTooltip(root.inputState, root.layoutFull, root.multipleLayouts)
    onPressed: function(button) {
      if (root.multipleInputs && button === Qt.LeftButton) {
        InputMethodState.cycle()
      } else if (root.multipleLayouts) {
        root.cycleLayout()
      }
    }
  }
}
