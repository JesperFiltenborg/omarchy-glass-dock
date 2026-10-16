import QtQuick
import Quickshell.Wayland

// One app in the Alt+Tab switcher: a live preview of its selected (or most
// recent) window, with the app icon, name and window count beneath.
Item {
  id: root

  required property var dock
  required property var theme
  required property string appId
  required property var windows
  property var shownWindow: null
  property bool selected: false

  signal hovered()
  signal clicked()

  readonly property int count: windows.length

  scale: selected ? 1.0 : 0.94
  Behavior on scale { enabled: root.theme.animate; NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

  Rectangle {
    anchors.fill: parent
    radius: root.theme.r(20)
    color: root.selected ? root.theme.selectedFill : root.theme.alpha(root.theme.text, 0.04)
    border.width: root.selected ? 2 : 1
    border.color: root.selected ? root.theme.selectedRim : root.theme.rimSoft
    Behavior on color { enabled: root.theme.animate; ColorAnimation { duration: 120 } }
  }

  Item {
    id: frame
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.margins: 10
    height: Math.round(root.width * 0.62)

    ScreencopyView {
      id: capture
      anchors.centerIn: parent
      captureSource: root.shownWindow ? root.shownWindow.wayland : null
      live: root.visible
      constraintSize: Qt.size(frame.width, frame.height)
      width: hasContent ? implicitWidth : frame.width
      height: hasContent ? implicitHeight : frame.height
    }

    Rectangle {
      anchors.fill: parent
      visible: !capture.hasContent
      radius: root.theme.r(10)
      color: root.theme.alpha(root.theme.text, 0.06)
      Image {
        anchors.centerIn: parent
        width: 64
        height: 64
        sourceSize: Qt.size(128, 128)
        source: root.dock.apps.iconFor(root.appId)
        opacity: 0.5
      }
    }
  }

  Image {
    id: icon
    anchors.left: parent.left
    anchors.leftMargin: 14
    anchors.top: frame.bottom
    anchors.topMargin: -18
    width: 44
    height: 44
    sourceSize: Qt.size(88, 88)
    source: root.dock.apps.iconFor(root.appId)
    smooth: true
    mipmap: true
  }

  Column {
    anchors.left: icon.right
    anchors.leftMargin: 10
    anchors.right: parent.right
    anchors.rightMargin: 12
    anchors.top: frame.bottom
    anchors.topMargin: 8
    spacing: 2

    Text {
      textFormat: Text.PlainText
      width: parent.width
      text: root.dock.apps.nameFor(root.appId)
      elide: Text.ElideRight
      color: root.theme.text
      font.family: root.theme.fontFamily
      font.pixelSize: 14
      font.bold: true
    }
    Text {
      textFormat: Text.PlainText
      width: parent.width
      text: root.shownWindow ? (root.shownWindow.title || "") : ""
      elide: Text.ElideRight
      color: root.theme.alpha(root.theme.text, 0.6)
      font.family: root.theme.fontFamily
      font.pixelSize: 11
    }
  }

  // Window-count badge on the preview corner: the "group" marker.
  Rectangle {
    visible: root.count > 1
    anchors.right: frame.right
    anchors.top: frame.top
    anchors.margins: 6
    height: 22
    width: Math.max(22, badge.implicitWidth + 12)
    radius: root.theme.r(11)
    color: root.theme.accent
    Text {
      textFormat: Text.PlainText
      id: badge
      anchors.centerIn: parent
      text: root.count
      color: root.theme.base
      font.family: root.theme.fontFamily
      font.pixelSize: 12
      font.bold: true
    }
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onEntered: root.hovered()
    onClicked: root.clicked()
  }
}
