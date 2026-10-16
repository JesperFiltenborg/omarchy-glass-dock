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
  // Reserve the dock's strip unless it floats over windows as an overlay.
  // With show-on-hover the strip stays reserved while hidden: that empty
  // area is what you hover to bring the dock back.
  exclusiveZone: settings.cfg.overlay ? 0 : shelfHeight + margin

  mask: Region {
    item: hotZone
    Region { item: popupHit }
  }

  // ---- magnification -------------------------------------------------------

  property real hoverPos: -1          // slot coordinate under the pointer, -1 when away
  property real lastHoverPos: -1
  // No zoom until the dock has finished sliding in: zooming mid-slide wobbles.
  property real zoomAmount: hoverPos >= 0 && revealProgress > 0.98 ? 1 : 0
  Behavior on zoomAmount { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

  function hoverAt(pos) {
    hoverPos = pos
    lastHoverPos = pos
    leaveTimer.stop()
  }

  // Largest zoom across the icons right now. The shelf grows by this much so
  // magnified icons stay inside its border instead of poking out of the top.
  readonly property real peakZoom: {
    const count = dock.windows.pinnedApps.length + dock.windows.runningApps.length
    let peak = 1
    for (let i = 0; i < count; i++) peak = Math.max(peak, zoomFor(i))
    return peak
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

  readonly property string popupAppId: popupItem ? popupItem.appId : ""

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
  onPopupKindChanged: updateReveal()

  // ---- show on hover --------------------------------------------------------------
  //
  // One hover zone (hotZone, inside `stage`) drives everything. While hidden it covers the
  // dock's resting footprint plus `revealArea` px around it; while shown, the
  // (possibly magnified) shelf plus the same margin. A short dwell before showing stops accidental reveals when the
  // pointer only passes through.

  readonly property bool hoverMode: settings.cfg.showOnHover
  property bool shown: false
  readonly property bool revealed: !hoverMode || shown || popupKind === "menu"

  // 0 = hidden, 1 = shown. Ease out when appearing, ease in when leaving.
  property real revealProgress: revealed ? 1 : 0
  Behavior on revealProgress {
    NumberAnimation {
      duration: win.revealed ? 260 : 190
      easing.type: win.revealed ? Easing.OutCubic : Easing.InCubic
    }
  }

  // A function, not a bound property: updateReveal() runs inside the
  // hover-changed handler, before a derived binding would have updated, so a
  // property here would always lag one event behind.
  function isEngaged() {
    return pointerInside.hovered || popupKind === "menu"
  }

  function updateReveal() {
    if (!hoverMode) return
    if (isEngaged()) {
      hideTimer.stop()
      if (!shown && !revealTimer.running) revealTimer.restart()
    } else {
      revealTimer.stop()
      if (shown) hideTimer.restart()
    }
  }

  Timer {
    id: revealTimer
    interval: win.settings.cfg.overlay ? 140 : 60
    onTriggered: if (win.isEngaged()) win.shown = true
  }

  Timer {
    id: hideTimer
    interval: win.settings.cfg.hideDelay
    onTriggered: if (!win.isEngaged()) win.shown = false
  }

  onHoverModeChanged: {
    shown = false
    updateReveal()
  }

  // Everything that takes pointer input lives in `stage`, so one HoverHandler
  // on it sees the pointer anywhere in the input region (hover always reaches
  // parents; a sibling zone *behind* the icons would lose it to their
  // MouseAreas and make the dock hide while you're on an icon).
  Item {
    id: stage
    anchors.fill: parent

    HoverHandler {
      id: pointerInside
      onHoveredChanged: win.updateReveal()
    }

    Item {
      id: hotZone
      // Same reach shown or hidden: a smaller keep-zone would hide the dock
      // straight after a pointer resting in the outer reveal area summoned it.
      readonly property int reach: win.hoverMode ? win.settings.cfg.revealArea : 0
      // Sideways the zone reaches six times further: the pointer usually
      // approaches the bottom edge somewhere off to the dock's side, and the
      // height above the dock (which overlaps windows in overlay mode) stays small.
      readonly property int sideReach: reach * 6
      readonly property real edge: win.revealed ? shelf.y : win.height - win.margin - win.shelfHeight
      x: Math.max(0, shelf.x - sideReach)
      width: Math.min(win.width, shelf.x + shelf.width + sideReach) - x
      y: Math.max(0, edge - reach)
      height: win.height - y
    }

    // ---- shelf -------------------------------------------------------------------

    Item {
      id: shelf
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.bottom: parent.bottom
      anchors.bottomMargin: win.margin
      width: row.width + win.padding * 2
      // Grows upward with magnification; the exclusive zone stays at shelfHeight,
      // so tiled windows don't move while hovering.
      height: win.shelfHeight + Math.round(win.iconSize * (win.peakZoom - 1))
      // Width follows the icons directly (no Behavior): an animated width lags
      // behind magnification and lets icons spill over the sides.
      visible: win.revealProgress > 0
      opacity: Math.min(1, win.revealProgress * 1.4)
      transform: Translate {
        y: (1 - win.revealProgress) * (win.shelfHeight + win.margin + 6)
      }

      Surface {
        anchors.fill: parent
        theme: win.theme
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

    // ---- popup host ----------------------------------------------------------------

    Item {
      id: popup
      readonly property bool open: win.popupKind !== "" && win.popupItem !== null
      width: loader.item ? loader.item.implicitWidth : 0
      height: loader.item ? loader.item.implicitHeight : 0
      x: Math.max(8, Math.min(win.popupAnchorX - width / 2, win.width - width - 8))
      // Previews and menus sit above the fully magnified shelf so they don't bob
      // as the zoom changes; tooltips hug the shelf.
      y: (win.popupKind === "tooltip" ? shelf.y : win.height - win.margin - win.shelfHeight - win.zoomHeadroom) - height - 12
      visible: opacity > 0
      opacity: open ? 1 : 0
      Behavior on opacity { NumberAnimation { duration: 130 } }
      transform: Translate {
        y: popup.open ? 0 : 8
        Behavior on y { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
      }

      HoverHandler {
        id: popupHover
        onHoveredChanged: {
          if (!hovered) leaveTimer.restart()
          win.updateReveal()
        }
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
      Surface {
        anchors.fill: parent
        theme: win.theme
        radius: win.theme.r(height / 2)
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
