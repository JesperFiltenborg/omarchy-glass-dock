import QtQuick
import Quickshell
import Quickshell.Wayland

// The dock on one monitor: a glass shelf anchored to the bottom edge, plus the
// popups that rise out of it (group previews, context menu, tooltip).
//
// The layer surface is taller than the shelf so magnified icons and popups can
// draw above it; `mask` keeps the transparent part click-through, and Hyprland
// only blurs pixels above the layer rule's ignore_alpha.
PanelWindow {
  id: win

  required property var dock
  required property var modelData

  readonly property var settings: dock.settings
  readonly property var theme: dock.theme
  readonly property int iconSize: settings.cfg.iconSize
  readonly property real magnification: Math.max(1, settings.cfg.magnification)
  readonly property int padding: Math.round(iconSize * 0.2)
  readonly property int spacing: Math.round(iconSize * 0.14)
  readonly property int shelfHeight: iconSize + padding * 2
  readonly property int margin: settings.cfg.margin
  readonly property int zoomHeadroom: Math.ceil(iconSize * (magnification - 1))
  readonly property int popupSpace: Math.max(Math.round(settings.cfg.previewWidth * 0.62) + 110, 460)

  screen: modelData
  color: "transparent"
  WlrLayershell.namespace: "glassdock"
  WlrLayershell.layer: WlrLayer.Top
  anchors {
    bottom: true
    left: true
    right: true
  }
  implicitHeight: margin + shelfHeight + zoomHeadroom + popupSpace
  exclusionMode: ExclusionMode.Normal
  exclusiveZone: settings.cfg.autoHide ? 0 : shelfHeight + margin

  mask: Region {
    item: shelfHit
    Region { item: popupHit }
    Region { item: trigger }
  }

  // ---- magnification -------------------------------------------------------

  property real hoverPos: -1          // slot coordinate under the pointer, -1 when away
  property real lastHoverPos: -1
  property real zoomAmount: hoverPos >= 0 ? 1 : 0
  Behavior on zoomAmount { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

  function hoverAt(pos) {
    hoverPos = pos
    lastHoverPos = pos
    leaveTimer.stop()
  }

  function zoomFor(slot) {
    if (magnification <= 1.001 || lastHoverPos < 0 || zoomAmount <= 0) return 1
    const range = Math.max(1, settings.cfg.magnificationRange)
    const d = Math.abs(slot + 0.5 - lastHoverPos)
    if (d >= range) return 1
    return 1 + (magnification - 1) * zoomAmount * (Math.cos(d / range * Math.PI) + 1) / 2
  }

  // ---- popups ------------------------------------------------------------------

  property string popupKind: ""       // "", "preview", "menu", "tooltip"
  property var popupItem: null
  property real popupAnchorX: 0
  property var hoveredItem: null
  property bool revealHeld: false

  readonly property string popupAppId: popupItem ? popupItem.appId : ""
  readonly property bool revealed: !settings.cfg.autoHide || revealHeld || popupKind === "menu"
    || (hoveredItem !== null) || popupHover.hovered

  function anchorTo(item) {
    popupItem = item
    popupAnchorX = item.mapToItem(win.contentItem, item.width / 2, 0).x
  }

  function openPopup(kind, item) {
    anchorTo(item)
    popupKind = kind
  }

  function openPreviewOrTooltip(item) {
    if (!item) return
    if (item.running && settings.cfg.previews) openPopup("preview", item)
    else openPopup("tooltip", item)
  }

  function openMenu(item) {
    previewTimer.stop()
    openPopup("menu", item)
  }

  function closePopups() {
    previewTimer.stop()
    popupKind = ""
    popupItem = null
  }

  function itemEntered(item) {
    hoveredItem = item
    leaveTimer.stop()
    if (popupKind === "menu") return
    if (popupKind !== "") openPreviewOrTooltip(item) // already browsing: switch instantly
    else previewTimer.restart()
  }

  function itemExited(item) {
    if (hoveredItem === item) hoveredItem = null
    previewTimer.stop()
    leaveTimer.restart()
  }

  Timer {
    id: previewTimer
    interval: win.settings.cfg.previewDelay
    onTriggered: win.openPreviewOrTooltip(win.hoveredItem)
  }

  Timer {
    id: leaveTimer
    interval: 260
    onTriggered: {
      if (!win.hoveredItem) win.hoverPos = -1
      if (!win.hoveredItem && !popupHover.hovered && win.popupKind !== "menu") win.closePopups()
    }
  }

  // A menu stays until used, the pointer has been gone a while, or focus moves.
  Timer {
    id: menuLeaveTimer
    interval: 900
    running: win.popupKind === "menu" && !popupHover.hovered && !win.hoveredItem
    onTriggered: win.closePopups()
  }

  Connections {
    target: win.dock.windows
    function onActiveWindowChanged() {
      if (win.popupKind === "menu") win.closePopups()
    }
  }

  onRevealedChanged: if (!revealed) closePopups()

  // ---- autohide ---------------------------------------------------------------

  Timer {
    id: hideTimer
    interval: win.settings.cfg.autoHideDelay
    onTriggered: win.revealHeld = false
  }

  Item {
    id: trigger
    anchors.bottom: parent.bottom
    anchors.horizontalCenter: parent.horizontalCenter
    width: shelf.width
    height: win.settings.cfg.autoHide ? 6 : 0
    HoverHandler {
      onHoveredChanged: if (hovered) { win.revealHeld = true; hideTimer.stop() }
    }
  }

  // ---- shelf -------------------------------------------------------------------

  Item {
    id: shelf
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: win.margin
    width: row.width + win.padding * 2
    height: win.shelfHeight
    transform: Translate {
      y: win.revealed ? 0 : win.shelfHeight + win.margin + 2
      Behavior on y { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
    }

    Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

    GlassSurface {
      anchors.fill: parent
      theme: win.theme
    }

    HoverHandler {
      onHoveredChanged: {
        if (hovered) { win.revealHeld = true; hideTimer.stop() }
        else hideTimer.restart()
      }
    }

    Row {
      id: row
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.bottom: parent.bottom
      anchors.bottomMargin: win.padding
      height: win.iconSize
      spacing: win.spacing

      Repeater {
        model: ScriptModel { values: win.dock.windows.pinnedApps }
        DockItem {
          required property string modelData
          required property int index
          anchors.bottom: parent.bottom
          dock: win.dock
          bar: win
          appId: modelData
          slot: index
        }
      }

      Rectangle {
        visible: win.settings.cfg.showRunningSeparator
          && win.dock.windows.pinnedApps.length > 0 && win.dock.windows.runningApps.length > 0
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Math.round(win.iconSize * 0.12)
        width: 1
        height: Math.round(win.iconSize * 0.76)
        color: win.theme.rim
      }

      Repeater {
        model: ScriptModel { values: win.dock.windows.runningApps }
        DockItem {
          required property string modelData
          required property int index
          anchors.bottom: parent.bottom
          dock: win.dock
          bar: win
          appId: modelData
          slot: win.dock.windows.pinnedApps.length + index
        }
      }
    }
  }

  // Input region for the shelf, including the headroom magnified icons grow into.
  Item {
    id: shelfHit
    x: shelf.x
    width: shelf.width
    y: win.revealed ? shelf.y - Math.round(win.zoomHeadroom * win.zoomAmount) : win.height
    height: win.revealed ? win.height - y : 0
  }

  // ---- popup host ----------------------------------------------------------------

  Item {
    id: popup
    readonly property bool open: win.popupKind !== "" && win.popupItem !== null
    width: loader.item ? loader.item.implicitWidth : 0
    height: loader.item ? loader.item.implicitHeight : 0
    x: Math.max(8, Math.min(win.popupAnchorX - width / 2, win.width - width - 8))
    y: shelf.y - height - 12 - (win.popupKind === "tooltip" ? Math.round(win.zoomHeadroom * win.zoomAmount) : win.zoomHeadroom)
    visible: opacity > 0
    opacity: open ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 130 } }
    transform: Translate {
      y: popup.open ? 0 : 8
      Behavior on y { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
    }

    HoverHandler {
      id: popupHover
      onHoveredChanged: if (!hovered) leaveTimer.restart()
    }

    Loader {
      id: loader
      active: win.popupKind !== ""
      sourceComponent: win.popupKind === "preview" ? previewComponent
        : win.popupKind === "menu" ? menuComponent
        : win.popupKind === "tooltip" ? tooltipComponent : null
    }
  }

  Item {
    id: popupHit
    x: popup.x
    y: popup.y
    width: popup.open ? popup.width : 0
    height: popup.open ? popup.height : 0
  }

  Component {
    id: previewComponent
    PreviewPopup {
      dock: win.dock
      bar: win
      appId: win.popupAppId
    }
  }

  Component {
    id: menuComponent
    ContextMenu {
      dock: win.dock
      bar: win
      appId: win.popupAppId
    }
  }

  Component {
    id: tooltipComponent
    Item {
      implicitWidth: label.implicitWidth + 28
      implicitHeight: 32
      GlassSurface {
        anchors.fill: parent
        theme: win.theme
        radius: height / 2
        tint: win.theme.tintStrong
      }
      Text {
        id: label
        anchors.centerIn: parent
        text: win.dock.apps.nameFor(win.popupAppId)
        color: win.theme.text
        font.family: win.theme.fontFamily
        font.pixelSize: win.theme.fontSize
      }
    }
  }
}
