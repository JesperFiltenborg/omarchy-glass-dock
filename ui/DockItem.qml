import QtQuick

// One app in the dock. Owns its icon, magnification, window-count dots and the
// launch bounce; everything else (previews, menus) is delegated to the bar.
//
//   Left click    launch / focus most recent window / step through windows
//   Middle click  open a new window
//   Right click   context menu
//   Wheel         cycle through the app's windows
//   Hover         live previews of every window in the group
Item {
  id: root

  required property var dock        // GlassDock root (settings, apps, windows, theme)
  required property var bar         // the Dock window this item lives in
  required property string appId
  required property int slot        // position used for magnification

  readonly property var settings: dock.settings
  readonly property var theme: dock.theme
  readonly property var windows: dock.windows.windowsOf(appId)
  readonly property int count: windows.length
  readonly property bool running: count > 0
  readonly property bool focused: dock.windows.activeAppId === appId
  readonly property bool hovered: mouse.containsMouse

  readonly property real base: settings.cfg.iconSize
  readonly property real zoom: bar.zoomFor(slot)

  property bool launching: false

  width: Math.round(base * zoom)
  height: Math.round(base * zoom)

  function centerInBar() {
    return mapToItem(bar.contentItem, width / 2, 0)
  }

  Item {
    id: lift
    anchors.fill: parent
    transform: Translate { id: liftShift }

    Image {
      id: icon
      anchors.fill: parent
      anchors.margins: Math.round(4 * root.zoom)
      source: root.dock.apps.iconFor(root.appId)
      sourceSize.width: Math.round(root.base * root.settings.cfg.magnification)
      sourceSize.height: Math.round(root.base * root.settings.cfg.magnification)
      fillMode: Image.PreserveAspectFit
      smooth: true
      mipmap: true
      asynchronous: true
      scale: mouse.pressed ? 0.9 : 1
      Behavior on scale { enabled: root.theme.animate; NumberAnimation { duration: 90 } }
    }

    SequentialAnimation {
      id: bounce
      loops: 3
      NumberAnimation { target: liftShift; property: "y"; to: -root.base * 0.35; duration: 260; easing.type: Easing.OutQuad }
      NumberAnimation { target: liftShift; property: "y"; to: 0; duration: 260; easing.type: Easing.InQuad }
    }
  }

  // Running indicator: one dot per window (capped), the focused app gets a pill.
  Row {
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.top: parent.bottom
    anchors.topMargin: 3
    spacing: 3
    visible: root.running
    Repeater {
      model: Math.min(root.count, root.settings.cfg.maxDots)
      Rectangle {
        required property int index
        width: root.focused && index === 0 ? 12 : 5
        height: 5
        radius: root.theme.r(2.5)
        color: root.focused ? root.theme.accent : root.theme.alpha(root.theme.text, 0.75)
        Behavior on width { enabled: root.theme.animate; NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
      }
    }
  }

  onCountChanged: if (count > 0) stopLaunching()

  function startLaunching() {
    launching = true
    if (theme.animate) bounce.restart()
    launchTimeout.restart()
  }

  function stopLaunching() {
    launching = false
    bounce.stop()
    liftShift.y = 0
  }

  Timer {
    id: launchTimeout
    interval: 4000
    onTriggered: root.stopLaunching()
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
    cursorShape: Qt.PointingHandCursor

    onPositionChanged: event => root.bar.hoverAt(root.slot + event.x / root.width)
    onEntered: root.bar.itemEntered(root)
    onExited: root.bar.itemExited(root)

    onClicked: event => {
      if (event.button === Qt.RightButton) {
        root.bar.openMenu(root)
        return
      }
      root.bar.closePopups()
      if (event.button === Qt.MiddleButton || !root.dock.windows.activateApp(root.appId)) {
        root.dock.apps.launch(root.appId)
        root.startLaunching()
      }
    }

    onWheel: event => {
      if (root.count < 2) return
      root.dock.windows.cycleApp(root.appId, event.angleDelta.y < 0 ? 1 : -1)
    }
  }
}
