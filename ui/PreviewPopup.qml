import QtQuick

// The window group for one app: a live thumbnail per window, most recent
// first. Click focuses, middle click or ✕ closes.
Item {
  id: root

  required property var dock
  required property var bar
  required property string appId

  readonly property var theme: dock.theme
  readonly property var windows: dock.windows.windowsOf(appId)
  readonly property int pad: 12
  // Shrink thumbnails rather than overflow the monitor when a group is large.
  readonly property int thumbWidth: Math.max(150, Math.min(dock.settings.cfg.previewWidth,
    Math.floor((bar.width * 0.85 - pad * 2) / Math.max(1, windows.length)) - thumbs.spacing))

  implicitWidth: Math.max(column.implicitWidth, 180) + pad * 2
  implicitHeight: column.implicitHeight + pad * 2

  onWindowsChanged: if (windows.length === 0) bar.closePopups()

  Surface {
    anchors.fill: parent
    theme: root.theme
    radius: root.theme.r(20)
    tint: root.theme.tintStrong
  }

  Column {
    id: column
    x: root.pad
    y: root.pad
    spacing: 8

    Row {
      spacing: 8
      leftPadding: 4
      Text {
        textFormat: Text.PlainText
        text: root.dock.apps.nameFor(root.appId)
        color: root.theme.text
        font.family: root.theme.fontFamily
        font.pixelSize: root.theme.fontSize
        font.bold: true
      }
      Text {
        textFormat: Text.PlainText
        visible: root.windows.length > 1
        text: root.windows.length + " windows"
        color: root.theme.alpha(root.theme.text, 0.6)
        font.family: root.theme.fontFamily
        font.pixelSize: root.theme.fontSize - 1
      }
    }

    Row {
      id: thumbs
      spacing: 6
      Repeater {
        model: root.windows
        WindowThumb {
          required property var modelData
          theme: root.theme
          toplevel: modelData
          implicitWidth: root.thumbWidth
          width: implicitWidth
          height: implicitHeight
          selected: modelData === root.dock.windows.activeWindow
          onActivated: {
            root.dock.windows.focusWindow(modelData)
            root.bar.closePopups()
          }
          onCloseRequested: root.dock.windows.closeWindow(modelData)
        }
      }
    }
  }
}
