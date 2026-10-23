import QtQuick
import QtMultimedia
import qs.Commons

// Stills decode through Image; motion wallpapers play muted and loop through
// QtMultimedia. The lock screen passes a generated poster for video
// backgrounds, so it stays on the image path.
Item {
  id: root

  property string path: ""
  property int version: 0
  // Unversioned images cache by path. A caller whose version changes with every
  // new file, as the lock's does, may cache too: the version is in the URL.
  property bool cached: version === 0
  // A caller that knows the size its screen needs, in physical pixels, sets
  // constrainDecode and decodeSize. The image then waits for that size rather
  // than decoding at the file's native size first.
  property bool constrainDecode: false
  property size decodeSize: Qt.size(0, 0)
  readonly property var current: video ? videoLoader.item : imageLoader.item
  readonly property bool ready: current ? current.ready : false
  // The file behind path could not be loaded, as when it was deleted.
  readonly property bool failed: current ? current.failed : false
  readonly property bool video: Util.isVideoPath(path)
  // Cache-bust images selected in a running lock session, so a theme switch
  // that replaces the file behind an unchanged path shows the new pixels.
  readonly property url imageUrl: path && !video ? Util.fileUrl(path) + (version ? "?v=" + version : "") : ""
  readonly property url videoUrl: video ? Util.fileUrl(path) : ""

  Loader {
    id: imageLoader
    anchors.fill: parent
    active: root.path !== "" && !root.video
    sourceComponent: imageComponent
  }

  Loader {
    id: videoLoader
    anchors.fill: parent
    active: root.videoUrl !== ""
    sourceComponent: videoComponent
  }

  Component {
    id: imageComponent

    Image {
      readonly property bool ready: status === Image.Ready
      readonly property bool failed: status === Image.Error
      source: !root.constrainDecode || root.decodeSize.width > 0 ? root.imageUrl : ""
      fillMode: Image.PreserveAspectCrop
      asynchronous: true
      cache: root.cached
      sourceSize.width: root.constrainDecode ? root.decodeSize.width : (root.version > 0 ? width : 0)
      sourceSize.height: root.constrainDecode ? root.decodeSize.height : (root.version > 0 ? height : 0)
    }
  }

  Component {
    id: videoComponent

    Item {
      readonly property bool ready: player.playbackState === MediaPlayer.PlayingState ||
        player.mediaStatus === MediaPlayer.LoadedMedia ||
        player.mediaStatus === MediaPlayer.BufferedMedia
      readonly property bool failed: player.error !== MediaPlayer.NoError

      AudioOutput {
        id: audioOutput
        muted: true
      }

      MediaPlayer {
        id: player
        source: root.videoUrl
        autoPlay: true
        loops: MediaPlayer.Infinite
        audioOutput: audioOutput
        videoOutput: output
        onErrorOccurred: function(error, errorString) {
          if (error !== MediaPlayer.NoError) console.warn("BackgroundMedia: video failed", errorString)
        }
      }

      VideoOutput {
        id: output
        anchors.fill: parent
        fillMode: VideoOutput.PreserveAspectCrop
      }
    }
  }
}
