import QtQuick
import Quickshell.Wayland

// Live thumbnail of one window with its title. Shared by the dock's group
// previews and the Alt+Tab switcher.
Item {
  id: root

  required property var theme
  required property var toplevel     // HyprlandToplevel
  property bool selected: false
  property bool showTitle: true
  property bool showClose: true
  property bool live: true

  signal activated()
  signal closeRequested()

  readonly property bool hovered: hover.hovered
  readonly property int titleHeight: showTitle ? 22 : 0
  readonly property string workspaceLabel: toplevel && toplevel.workspace ? String(toplevel.workspace.name) : ""

  implicitWidth: 240
  implicitHeight: Math.round(implicitWidth * 0.62) + titleHeight + 12

  Rectangle {
    anchors.fill: parent
    radius: root.theme.r(14)
    color: root.selected ? root.theme.selectedFill : (root.hovered ? root.theme.hoverFill : "transparent")
    border.width: root.selected ? 2 : 0
    border.color: root.theme.selectedRim
    Behavior on color { ColorAnimation { duration: 120 } }
  }

  Item {
    id: frame
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.margins: 6
    height: parent.height - root.titleHeight - 12

    ScreencopyView {
      id: capture
      anchors.centerIn: parent
      captureSource: root.toplevel ? root.toplevel.wayland : null
      live: root.live && root.visible
      constraintSize: Qt.size(frame.width, frame.height)
      width: hasContent ? implicitWidth : frame.width
      height: hasContent ? implicitHeight : frame.height
      opacity: hasContent ? 1 : 0
      Behavior on opacity { NumberAnimation { duration: 140 } }
    }

    // Placeholder until the first frame arrives (or for apps that refuse capture).
    Rectangle {
      anchors.fill: parent
      radius: root.theme.r(8)
      visible: !capture.hasContent
      color: root.theme.alpha(root.theme.text, 0.06)
      border.width: 1
      border.color: root.theme.rimSoft
    }
  }

  Text {
    visible: root.showTitle
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 6
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.leftMargin: 10
    anchors.rightMargin: 10
    height: root.titleHeight
    verticalAlignment: Text.AlignVCenter
    horizontalAlignment: Text.AlignHCenter
    elide: Text.ElideMiddle
    color: root.theme.text
    font.family: root.theme.fontFamily
    font.pixelSize: 12
    text: (root.toplevel ? root.toplevel.title : "") || ""
  }

  // Workspace chip, so same-app windows spread across workspaces are easy to tell apart.
  Rectangle {
    visible: root.workspaceLabel !== ""
    anchors.left: parent.left
    anchors.top: parent.top
    anchors.margins: 10
    height: 18
    width: wsText.implicitWidth + 12
    radius: root.theme.r(9)
    color: root.theme.alpha(root.theme.base, 0.7)
    border.width: 1
    border.color: root.theme.rimSoft
    Text {
      id: wsText
      anchors.centerIn: parent
      text: root.workspaceLabel
      color: root.theme.text
      font.family: root.theme.fontFamily
      font.pixelSize: 10
    }
  }

  HoverHandler { id: hover }

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton | Qt.MiddleButton
    cursorShape: Qt.PointingHandCursor
    onClicked: event => {
      if (event.button === Qt.MiddleButton) root.closeRequested()
      else root.activated()
    }
  }

  Rectangle {
    id: closeButton
    visible: root.showClose && root.hovered
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.margins: 8
    width: 22
    height: 22
    radius: root.theme.r(11)
    color: closeMouse.containsMouse ? root.theme.urgent : root.theme.alpha(root.theme.base, 0.8)
    border.width: 1
    border.color: root.theme.rim
    Text {
      anchors.centerIn: parent
      text: "✕"
      color: root.theme.text
      font.pixelSize: 11
    }
    MouseArea {
      id: closeMouse
      anchors.fill: parent
      hoverEnabled: true
      onClicked: root.closeRequested()
    }
  }
}
