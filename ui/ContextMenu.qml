import QtQuick

// Right-click menu for a dock item: jump to any of the app's windows, open a
// new one, pin/unpin, or close them all.
Item {
  id: root

  required property var dock
  required property var bar
  required property string appId

  readonly property var theme: dock.theme
  readonly property var windows: dock.windows.windowsOf(appId)
  readonly property bool pinned: dock.settings.isPinned(appId)
  readonly property int maxWindowRows: 8

  implicitWidth: 280
  implicitHeight: column.implicitHeight + 16

  component MenuRow: Rectangle {
    id: row
    property string label
    property string detail: ""
    property bool destructive: false
    property bool emphasized: false
    signal triggered()

    width: column.width
    height: 30
    radius: root.theme.r(8)
    color: rowMouse.containsMouse
      ? (destructive ? root.theme.alpha(root.theme.urgent, 0.35) : root.theme.hoverFill)
      : "transparent"

    Text {
      textFormat: Text.PlainText
      anchors.left: parent.left
      anchors.right: detailText.left
      anchors.leftMargin: 10
      anchors.rightMargin: 8
      anchors.verticalCenter: parent.verticalCenter
      text: row.label
      elide: Text.ElideRight
      color: root.theme.text
      font.family: root.theme.fontFamily
      font.pixelSize: root.theme.fontSize
      font.bold: row.emphasized
    }
    Text {
      textFormat: Text.PlainText
      id: detailText
      anchors.right: parent.right
      anchors.rightMargin: 10
      anchors.verticalCenter: parent.verticalCenter
      text: row.detail
      color: root.theme.alpha(root.theme.text, 0.55)
      font.family: root.theme.fontFamily
      font.pixelSize: root.theme.fontSize - 2
    }
    MouseArea {
      id: rowMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: {
        row.triggered()
        root.bar.closePopups()
      }
    }
  }

  component Divider: Rectangle {
    width: column.width
    height: 1
    color: root.theme.rimSoft
  }

  Surface {
    anchors.fill: parent
    theme: root.theme
    radius: root.theme.r(16)
    tint: root.theme.tintStrong
  }

  Column {
    id: column
    x: 8
    y: 8
    width: root.implicitWidth - 16
    spacing: 2

    Item {
      width: column.width
      height: 40
      Image {
        id: headerIcon
        anchors.left: parent.left
        anchors.leftMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        width: 26
        height: 26
        sourceSize: Qt.size(52, 52)
        source: root.dock.apps.iconFor(root.appId)
      }
      Text {
        textFormat: Text.PlainText
        anchors.left: headerIcon.right
        anchors.leftMargin: 10
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        text: root.dock.apps.nameFor(root.appId)
        elide: Text.ElideRight
        color: root.theme.text
        font.family: root.theme.fontFamily
        font.pixelSize: root.theme.fontSize + 1
        font.bold: true
      }
    }

    Divider { visible: root.windows.length > 0 }

    Repeater {
      model: root.windows.slice(0, root.maxWindowRows)
      MenuRow {
        required property var modelData
        label: modelData.title || "Untitled"
        detail: modelData.workspace ? "ws " + modelData.workspace.name : ""
        emphasized: modelData === root.dock.windows.activeWindow
        onTriggered: root.dock.windows.focusWindow(modelData)
      }
    }

    Divider {}

    MenuRow {
      label: "New Window"
      onTriggered: root.dock.apps.launch(root.appId)
    }
    MenuRow {
      label: root.pinned ? "Remove from Dock" : "Keep in Dock"
      onTriggered: root.dock.settings.togglePin(root.appId)
    }
    Divider {}

    MenuRow {
      label: "Dock Settings…"
      onTriggered: root.dock.settingsWindow.open()
    }
    MenuRow {
      visible: root.windows.length > 0
      destructive: true
      label: root.windows.length > 1 ? "Close " + root.windows.length + " Windows" : "Close Window"
      onTriggered: root.dock.windows.closeApp(root.appId)
    }
  }
}
