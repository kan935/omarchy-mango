// Workspace switcher: numbers for the other workspaces, a square for the
// one you are on. Drop-in replacement for the stock omarchy.workspaces module.
//
// Settings (in the bar.layout entry of ~/.config/omarchy/shell.json):
//   { "id": "workspaces-squares", "type": "qml",
//     "square": "□",        // optional glyph instead of the drawn box
//     "slotWidth": 22, "spacing": 4, "fontSize": 12 }
import QtQuick
import Quickshell.Io

Item {
  id: root

  // Filled in by the bar after loading.
  property var bar: null
  property string moduleName: ""
  property var settings: null
  property string screenName: ""

  // Mango owns ten tags per monitor, and each bar follows the monitor it is
  // painted on. `mmsg watch all-tags` is the only source of truth for both.
  readonly property int slots: 10
  property var monitorTags: []
  readonly property var activeTag: {
    for (var i = 0; i < root.monitorTags.length; i++) {
      if (root.monitorTags[i].is_active) return root.monitorTags[i]
    }
    return null
  }

  // Workspace ids shown on the bar, refreshed as the tags change.
  readonly property var ids: workspaceIds()

  readonly property var cfg: settings || {}
  readonly property bool vertical: bar ? bar.vertical : false
  readonly property real barScale: bar ? (barSize / 26) : 1
  readonly property real slotHeight: bar ? bar.barSize : 26
  readonly property real slotWidth: Number(cfg.slotWidth) > 0
    ? Number(cfg.slotWidth) : Math.round(22 * barScale)
  readonly property real spacing: Number(cfg.spacing) > 0
    ? Number(cfg.spacing) : Math.round(4 * barScale)
  readonly property real fontSize: Number(cfg.fontSize) > 0
    ? Number(cfg.fontSize) : Math.round(12 * barScale)
  readonly property bool hasSquareGlyph: typeof cfg.square === "string" && cfg.square !== ""
  readonly property color fg: bar ? (bar.barForeground || bar.foreground) : "white"
  readonly property color urgentColor: bar ? bar.urgent : "red"

  function readTags(line) {
    var data
    try {
      data = JSON.parse(String(line || ""))
    } catch (error) {
      return
    }

    var monitors = data.all_tags || []
    for (var i = 0; i < monitors.length; i++) {
      if (String(monitors[i].monitor || "") === root.screenName) {
        root.monitorTags = monitors[i].tags || []
        return
      }
    }

    if (monitors.length === 1 && !root.screenName) {
      root.monitorTags = monitors[0].tags || []
    }
  }

  function tagById(id) {
    for (var i = 0; i < root.monitorTags.length; i++) {
      var tag = root.monitorTags[i]
      if (Number(tag.index) === id) return tag
    }
    return null
  }

  // The first five tags, plus any of the rest that hold work or need attention.
  function workspaceIds() {
    var ids = [1, 2, 3, 4, 5]

    for (var i = 0; i < root.monitorTags.length; i++) {
      var tag = root.monitorTags[i]
      var id = Number(tag.index)
      if (!(id > 5 && id <= root.slots)) continue
      if (tag.is_active || tag.is_urgent || Number(tag.client_count) > 0) ids.push(id)
    }

    ids.sort(function(left, right) { return left - right })
    return ids
  }

  function handlePress(id, isFocused) {
    if (!bar) return

    // Clicking the focused workspace cycles its layout, like the stock widget.
    if (isFocused) {
      bar.run("omarchy-mango-workspace-layout-toggle")
      return
    }

    var command = "mmsg dispatch view," + id
    if (root.screenName) command = "mmsg dispatch focusmon," + root.screenName + " && " + command
    bar.run(command)
  }

  // A wheel notch moves one tag along the row; a touchpad adds its smaller
  // deltas until they make a notch's worth.
  property real wheelAccumulator: 0

  function scrollWorkspaces(delta) {
    delta = Math.max(-120, Math.min(120, delta))
    if (wheelAccumulator * delta < 0) wheelAccumulator = 0
    var total = wheelAccumulator + delta
    var steps = total < 0 ? Math.ceil(total / 120) : Math.floor(total / 120)
    wheelAccumulator = total - steps * 120
    if (steps === 0) return

    var ids = workspaceIds()
    var index = ids.indexOf(activeTag ? Number(activeTag.index) : -1)
    if (index === -1) return
    var target = ids[Math.max(0, Math.min(ids.length - 1, index - steps))]
    if (target !== ids[index]) handlePress(target, false)
  }

  implicitWidth: vertical
    ? slotHeight
    : (ids.length * slotWidth + Math.max(0, ids.length - 1) * spacing)
  implicitHeight: vertical
    ? (ids.length * slotHeight + Math.max(0, ids.length - 1) * spacing)
    : slotHeight

  Grid {
    id: grid
    anchors.fill: parent
    columns: root.vertical ? 1 : root.ids.length
    rows: root.vertical ? root.ids.length : 1
    columnSpacing: root.vertical ? 0 : root.spacing
    rowSpacing: root.vertical ? root.spacing : 0

    Repeater {
      model: root.ids

      Item {
        id: slot

        required property int modelData

        readonly property var tag: root.tagById(modelData)
        readonly property bool occupied: tag !== null && Number(tag.client_count) > 0
        readonly property bool focused: tag !== null && tag.is_active
        readonly property bool urgent: tag !== null && tag.is_urgent
        readonly property color tone: urgent ? root.urgentColor : root.fg

        width: root.vertical ? root.slotHeight : root.slotWidth
        height: root.slotHeight
        opacity: occupied || focused || urgent ? 1 : 0.45

        Behavior on opacity {
          NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
        }

        // The number, or the square glyph when one is configured.
        Text {
          anchors.centerIn: parent
          visible: !(slot.focused && !root.hasSquareGlyph)
          text: slot.focused && root.hasSquareGlyph
            ? root.cfg.square
            : (slot.modelData === 10 ? "0" : String(slot.modelData))
          color: slot.tone
          font.family: root.bar ? root.bar.fontFamily : "monospace"
          font.pixelSize: root.fontSize
          horizontalAlignment: Text.AlignHCenter
          verticalAlignment: Text.AlignVCenter
        }

        // No glyph configured: draw the outlined square for the focused one.
        Rectangle {
          anchors.centerIn: parent
          visible: slot.focused && !root.hasSquareGlyph
          width: Math.round(10 * root.barScale)
          height: width
          radius: Math.round(2.5 * root.barScale)
          color: "transparent"
          border.width: Math.max(1, Math.round(1.5 * root.barScale))
          border.color: slot.tone
        }

        MouseArea {
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onEntered: if (root.bar) root.bar.showTooltip(slot, "Workspace " + slot.modelData)
          onExited: if (root.bar) root.bar.hideTooltip(slot)
          onClicked: root.handlePress(slot.modelData, slot.focused)
          onWheel: function(wheel) { root.scrollWorkspaces(wheel.angleDelta.y) }
        }
      }
    }
  }

  Process {
    id: watchProc
    command: ["mmsg", "watch", "all-tags"]
    running: true
    stdout: SplitParser { onRead: function(line) { root.readTags(line) } }
    onExited: watchRestart.start()
  }

  Timer {
    id: watchRestart
    interval: 1000
    onTriggered: watchProc.running = true
  }
}
