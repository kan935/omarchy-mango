import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "omarchy.workspaces"

  // Mango owns ten tags per monitor, and each bar follows the monitor it is
  // painted on. `watch all-tags` is the only source of truth for both.
  readonly property int slots: 10
  property var monitorTags: []
  readonly property var activeTag: {
    for (var i = 0; i < root.monitorTags.length; i++) {
      if (root.monitorTags[i].is_active) return root.monitorTags[i]
    }
    return null
  }

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
      if (Number(root.monitorTags[i].index) === id) return root.monitorTags[i]
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

  function focusWorkspace(id) {
    if (!root.bar) return
    var command = "mmsg dispatch view," + id
    if (root.screenName) command = "mmsg dispatch focusmon," + root.screenName + " && " + command
    root.bar.run(command)
  }

  function cycleLayout() {
    if (!root.bar || !root.activeTag) return
    root.bar.run("omarchy-mango-workspace-layout-toggle")
  }

  // A wheel notch moves one tag along the row; a touchpad adds its smaller
  // deltas until they make a notch's worth.
  property real wheelAccumulator: 0

  function scrollWorkspaces(delta) {
    var wheel = Util.wheelSteps(root.wheelAccumulator, delta)
    root.wheelAccumulator = wheel.remainder
    if (wheel.steps === 0) return

    var ids = root.workspaceIds()
    var index = ids.indexOf(root.activeTag ? Number(root.activeTag.index) : -1)
    if (index === -1) return
    var target = ids[Util.clamp(index - wheel.steps, 0, ids.length - 1)]
    if (target !== ids[index]) root.focusWorkspace(target)
  }

  readonly property real trailingGap: root.vertical ? 0 : Style.spaceReal(1.5)

  implicitWidth: grid.implicitWidth + trailingGap
  implicitHeight: grid.implicitHeight

  GridLayout {
    id: grid
    anchors.fill: parent
    anchors.rightMargin: root.trailingGap
    columns: root.vertical ? 1 : root.workspaceIds().length
    columnSpacing: root.vertical ? 0 : Style.space(1)
    rowSpacing: root.vertical ? Style.space(2) : 0

    Repeater {
      model: root.workspaceIds()

      WidgetButton {
        required property int modelData

        readonly property var tag: root.tagById(modelData)
        readonly property bool occupied: tag !== null && Number(tag.client_count) > 0
        readonly property bool focused: tag !== null && tag.is_active
        readonly property bool urgent: tag !== null && tag.is_urgent

        bar: root.bar
        text: modelData === 10 ? "0" : String(modelData)
        active: urgent
        opacity: occupied || focused || urgent ? 1 : 0.5
        horizontalMargin: 6
        verticalPadding: 6
        fixedWidth: root.vertical ? root.barSize : Style.space(20)
        fixedHeight: root.barSize
        onPressed: function() {
          if (focused) root.cycleLayout()
          else root.focusWorkspace(modelData)
        }
        onWheelMoved: function(delta) { root.scrollWorkspaces(delta) }
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
