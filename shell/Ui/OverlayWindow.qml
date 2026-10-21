import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons as Commons

// Map a fresh fullscreen surface on each open. Keep its first frames
// transparent until Qt receives the output's scale, so it opens sharp without
// retaining a parked surface that can be closed when a monitor disconnects.
PanelWindow {
  id: window

  // Whether the overlay is showing. Drive this instead of visible.
  property bool shown: false
  property int shownLayer: WlrLayer.Overlay
  property int shownKeyboardFocus: WlrKeyboardFocus.Exclusive

  property var targetScreen: null

  // Wait for fullscreen geometry so no smaller opening frame is stretched
  // across the output. Mango reports the focused output through the bar; the
  // shell is single-output for now, so the first screen is the safe target.
  readonly property bool contentReady: shown && backingWindowVisible && !!targetScreen
    && width === targetScreen.width && height === targetScreen.height
  property bool contentRevealed: false

  onContentReadyChanged: {
    contentRevealed = false
    // Resize and scale notifications arrive while Qt is still updating the
    // window. Reveal on the next turn, once its content layout has caught up.
    if (contentReady) Qt.callLater(function() {
      if (window.contentReady) window.contentRevealed = true
    })
  }

  function focusedScreen() {
    return Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
  }

  onShownChanged: targetScreen = shown ? focusedScreen() : null

  Connections {
    target: Quickshell
    function onScreensChanged() {
      if (window.shown && Quickshell.screens.indexOf(window.targetScreen) < 0) {
        window.targetScreen = null
        // Let the removed output finish closing its old window before mapping
        // a replacement, rather than recreating it during Qt's teardown.
        Qt.callLater(function() {
          if (window.shown && !window.targetScreen) window.targetScreen = window.focusedScreen()
        })
      }
    }
  }

  visible: shown && !!targetScreen
  screen: targetScreen
  anchors { top: true; left: true; bottom: true; right: true }
  color: "transparent"
  exclusionMode: ExclusionMode.Ignore
  WlrLayershell.layer: shownLayer
  WlrLayershell.keyboardFocus: shownKeyboardFocus

  // Opacity preserves keyboard handling while the scale arrives, including
  // search keystrokes and Escape pressed immediately after opening.
  Binding {
    target: window.contentItem
    property: "opacity"
    value: window.contentRevealed ? 1 : 0
  }

  // Right-to-left languages read the overlay mirrored.
  Binding {
    target: window.contentItem
    property: "LayoutMirroring.enabled"
    value: Commons.I18n.rightToLeft
  }
  Binding {
    target: window.contentItem
    property: "LayoutMirroring.childrenInherit"
    value: true
  }
}
