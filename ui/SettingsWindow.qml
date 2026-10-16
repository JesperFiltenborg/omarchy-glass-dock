import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.Commons
import "../core/lib/settings.mjs" as SettingsLogic
import "../core/lib/keys.mjs" as KeyLogic

// Glass settings window. Every control writes straight to settings.cfg, which
// persists to ~/.config/omarchy/glassdock.json and applies live.
//
// Open with `omarchy-shell glassdock settings`, Super+Space → System →
// Dock Settings, or "Dock Settings…" in any dock item's right-click menu.
PanelWindow {
  id: root

  required property var dock

  readonly property var settings: dock.settings
  readonly property var cfg: dock.settings.cfg
  readonly property var theme: dock.theme

  property bool opened: false
  // True while the show/hide key recorder listens; GlassDock suspends the
  // bind meanwhile so the current combo reaches this window.
  property bool recordingKey: false

  function open() { opened = true }
  function close() {
    opened = false
    recordingKey = false
  }
  function toggle() { opened = !opened }

  visible: opened
  screen: {
    const name = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""
    return Quickshell.screens.find(s => s.name === name) || Quickshell.screens[0]
  }
  color: "transparent"
  WlrLayershell.namespace: "glassdock-settings"
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
  exclusionMode: ExclusionMode.Ignore
  // Unanchored: the compositor centres it.
  implicitWidth: 620
  implicitHeight: Math.min(860, (screen ? screen.height : 1080) - 120)

  // ---- controls -----------------------------------------------------------------

  component Label: Text {
    color: root.theme.text
    font.family: root.theme.fontFamily
    font.pixelSize: root.theme.fontSize
  }

  // Collapsible group of settings. Click the header to fold it; the open/closed
  // state is remembered for as long as the shell runs.
  component Section: Column {
    id: section
    property string title
    readonly property bool expanded: !root.collapsed[title]
    default property alias content: inner.data

    width: parent ? parent.width : 0
    spacing: 0
    topPadding: 6

    Rectangle {
      width: parent.width
      height: 34
      radius: root.theme.r(10)
      color: headerMouse.containsMouse ? root.theme.alpha(root.theme.text, 0.05) : "transparent"

      Text {
        id: chevron
        anchors.left: parent.left
        anchors.leftMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        text: "›"
        rotation: section.expanded ? 90 : 0
        color: root.theme.alpha(root.theme.text, 0.6)
        font.family: root.theme.fontFamily
        font.pixelSize: 16
        Behavior on rotation { enabled: root.theme.animate; NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
      }
      Text {
        anchors.left: chevron.right
        anchors.leftMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        text: section.title.toUpperCase()
        color: root.theme.alpha(root.theme.text, section.expanded ? 0.6 : 0.85)
        font.family: root.theme.fontFamily
        font.pixelSize: 11
        font.letterSpacing: 1.2
        font.bold: true
      }
      MouseArea {
        id: headerMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggleSection(section.title)
      }
    }

    Item {
      width: parent.width
      height: section.expanded ? inner.implicitHeight : 0
      clip: true
      Behavior on height { enabled: root.theme.animate; NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

      Column {
        id: inner
        width: parent.width
        spacing: 4
        topPadding: 2
        bottomPadding: 4
        opacity: section.expanded ? 1 : 0
        Behavior on opacity { enabled: root.theme.animate; NumberAnimation { duration: 160 } }
      }
    }
  }

  component Setting: Item {
    id: setting
    property string label
    property string hint: ""
    default property alias control: slot.data

    width: parent ? parent.width : 0
    height: Math.max(44, labels.implicitHeight + 14)

    Rectangle {
      anchors.fill: parent
      radius: root.theme.r(10)
      color: rowHover.hovered ? root.theme.alpha(root.theme.text, 0.05) : "transparent"
    }
    HoverHandler { id: rowHover }

    Column {
      id: labels
      anchors.left: parent.left
      anchors.leftMargin: 12
      anchors.right: slot.left
      anchors.rightMargin: 12
      anchors.verticalCenter: parent.verticalCenter
      spacing: 2
      Label { width: parent.width; text: setting.label; elide: Text.ElideRight }
      Label {
        visible: setting.hint !== ""
        width: parent.width
        text: setting.hint
        wrapMode: Text.WordWrap
        color: root.theme.alpha(root.theme.text, 0.5)
        font.pixelSize: 11
      }
    }

    Item {
      id: slot
      anchors.right: parent.right
      anchors.rightMargin: 12
      anchors.verticalCenter: parent.verticalCenter
      width: childrenRect.width
      height: childrenRect.height
    }
  }

  component Switch: Item {
    id: sw
    property bool checked
    signal toggled(bool value)

    width: 46
    height: 26

    Rectangle {
      anchors.fill: parent
      radius: root.theme.r(height / 2)
      color: root.theme.switchTrack(sw.checked)
      border.width: 1
      border.color: root.theme.rim
      Behavior on color { enabled: root.theme.animate; ColorAnimation { duration: 140 } }
    }
    Rectangle {
      width: 20
      height: 20
      radius: root.theme.r(10)
      y: 3
      x: sw.checked ? sw.width - width - 3 : 3
      color: root.theme.switchKnob(sw.checked)
      Behavior on x { enabled: root.theme.animate; NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
    }
    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      onClicked: sw.toggled(!sw.checked)
    }
  }

  component Slider: Item {
    id: slider
    property real from: 0
    property real to: 1
    property real stepSize: 1
    property real value: 0
    property int decimals: 0
    property string suffix: ""
    signal moved(real value)

    readonly property real fraction: Math.max(0, Math.min(1, (value - from) / (to - from)))

    width: 240
    height: 26

    function setFromX(x) {
      const f = Math.max(0, Math.min(1, x / track.width))
      const raw = from + f * (to - from)
      const stepped = Math.round(raw / stepSize) * stepSize
      moved(Number(Math.max(from, Math.min(to, stepped)).toFixed(4)))
    }

    Item {
      id: track
      anchors.left: parent.left
      anchors.right: valueText.left
      anchors.rightMargin: 12
      anchors.verticalCenter: parent.verticalCenter
      height: 26

      Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: 6
        radius: root.theme.r(3)
        color: root.theme.sliderTrack
      }
      Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width * slider.fraction
        height: 6
        radius: root.theme.r(3)
        color: root.theme.sliderFill
      }
      Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        x: (parent.width - width) * slider.fraction
        width: 18
        height: 18
        radius: root.theme.r(9)
        color: root.theme.sliderKnob
        border.width: 1
        border.color: root.theme.rim
        scale: drag.pressed ? 1.15 : 1
        Behavior on scale { enabled: root.theme.animate; NumberAnimation { duration: 100 } }
      }
      MouseArea {
        id: drag
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        preventStealing: true
        onPressed: event => slider.setFromX(event.x)
        onPositionChanged: event => { if (pressed) slider.setFromX(event.x) }
        onWheel: event => {
          const dir = event.angleDelta.y > 0 ? 1 : -1
          slider.moved(Math.max(slider.from, Math.min(slider.to,
            Number((slider.value + dir * slider.stepSize).toFixed(4)))))
        }
      }
    }

    Label {
      id: valueText
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      width: 54
      horizontalAlignment: Text.AlignRight
      text: Number(slider.value).toFixed(slider.decimals) + slider.suffix
      font.features: { "tnum": 1 }
    }
  }

  component Button: Rectangle {
    id: button
    property string text
    property bool destructive: false
    signal clicked()

    width: buttonLabel.implicitWidth + 28
    height: 32
    radius: root.theme.r(10)
    color: buttonMouse.containsMouse
      ? (destructive ? root.theme.alpha(root.theme.urgent, 0.4) : root.theme.hoverFill)
      : root.theme.alpha(root.theme.text, 0.06)
    border.width: 1
    border.color: root.theme.rimSoft

    Label {
      id: buttonLabel
      anchors.centerIn: parent
      text: button.text
    }
    MouseArea {
      id: buttonMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: button.clicked()
    }
  }

  component IconButton: Rectangle {
    id: iconButton
    property string glyph
    property bool destructive: false
    property bool enabledState: true
    signal clicked()

    width: 28
    height: 28
    radius: root.theme.r(8)
    opacity: enabledState ? 1 : 0.3
    color: iconMouse.containsMouse && enabledState
      ? (destructive ? root.theme.alpha(root.theme.urgent, 0.45) : root.theme.hoverFill)
      : "transparent"
    Label {
      anchors.centerIn: parent
      text: iconButton.glyph
      font.pixelSize: 13
    }
    MouseArea {
      id: iconMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: iconButton.enabledState ? Qt.PointingHandCursor : Qt.ArrowCursor
      onClicked: if (iconButton.enabledState) iconButton.clicked()
    }
  }

  component Chip: Rectangle {
    id: chip
    property string text
    property bool selected
    signal clicked()

    width: chipLabel.implicitWidth + 24
    height: 28
    radius: root.theme.r(14)
    color: selected ? root.theme.selectedFill : (chipMouse.containsMouse ? root.theme.hoverFill : "transparent")
    border.width: 1
    border.color: selected ? root.theme.selectedRim : root.theme.rimSoft
    Label {
      id: chipLabel
      anchors.centerIn: parent
      text: chip.text
      font.pixelSize: 12
    }
    MouseArea {
      id: chipMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: chip.clicked()
    }
  }

  // Key combination field: click it, then press the keys. Esc cancels. While
  // it listens it holds keyboard focus and sets root.recordingKey.
  component KeyRecorder: Rectangle {
    id: recorder
    property string combo
    property string problem: ""
    readonly property bool recording: root.recordingKey
    signal recorded(string combo)

    function start() {
      problem = ""
      root.recordingKey = true
      forceActiveFocus()
    }

    function stop() {
      root.recordingKey = false
      keyRoot.forceActiveFocus()
    }

    width: Math.max(140, recorderLabel.implicitWidth + 24)
    height: 28
    radius: root.theme.r(14)
    color: recording ? root.theme.selectedFill : (recorderMouse.containsMouse ? root.theme.hoverFill : "transparent")
    border.width: 1
    border.color: recording ? root.theme.selectedRim : root.theme.rimSoft

    Keys.onPressed: event => {
      event.accepted = true
      if (event.key === Qt.Key_Escape) {
        recorder.stop()
        return
      }
      const result = KeyLogic.comboFromKey(event.key, event.modifiers)
      if (result.pending) return
      if (result.error) {
        recorder.problem = result.error
        return
      }
      recorder.stop()
      recorder.recorded(result.combo)
    }

    Label {
      id: recorderLabel
      anchors.centerIn: parent
      text: recorder.recording ? (recorder.problem || "Press keys… (Esc cancels)") : KeyLogic.formatCombo(recorder.combo)
      font.pixelSize: 12
    }
    MouseArea {
      id: recorderMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: recorder.recording ? recorder.stop() : recorder.start()
    }
  }

  // Design picker card with a small drawn sample of the style it selects.
  component StyleCard: Rectangle {
    id: card
    property string key
    property string title
    property string description
    readonly property bool selected: (root.cfg.style || "glass") === key

    width: (parent ? parent.width : 0) / 2 - 5
    height: 150
    radius: root.theme.r(14)
    color: selected ? root.theme.selectedFill : (cardMouse.containsMouse ? root.theme.hoverFill : root.theme.alpha(root.theme.text, 0.04))
    border.width: selected ? 2 : 1
    border.color: selected ? root.theme.selectedRim : root.theme.rimSoft

    // Sample: a three-icon dock over a striped "wallpaper".
    Rectangle {
      id: sample
      anchors.top: parent.top
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.margins: 12
      height: 70
      radius: root.theme.r(8)
      clip: true
      gradient: Gradient {
        orientation: Gradient.Horizontal
        GradientStop { position: 0.0; color: root.theme.alpha(root.theme.accent, 0.55) }
        GradientStop { position: 1.0; color: root.theme.alpha(root.theme.urgent, 0.45) }
      }

      Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 10
        width: 112
        height: 34
        radius: card.key === "glass" ? 12 : Math.min(12, Style.cornerRadius)
        color: card.key === "glass" ? root.theme.alpha(root.theme.base, 0.35) : Color.bar.background
        border.width: card.key === "glass" ? 1 : Math.max(1, Style.space(2))
        border.color: card.key === "glass" ? Qt.rgba(1, 1, 1, 0.35) : Color.popups.border

        Rectangle {
          visible: card.key === "glass"
          anchors.fill: parent
          anchors.margins: 1
          radius: 11
          gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.22) }
            GradientStop { position: 0.6; color: Qt.rgba(1, 1, 1, 0) }
          }
        }

        Row {
          anchors.centerIn: parent
          spacing: 8
          Repeater {
            model: 3
            Rectangle {
              required property int index
              width: 20
              height: 20
              radius: card.key === "glass" ? 6 : Math.min(6, Style.cornerRadius)
              color: root.theme.alpha(root.theme.text, index === 1 ? 0.85 : 0.55)
            }
          }
        }
      }
    }

    Column {
      anchors.top: sample.bottom
      anchors.topMargin: 10
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.leftMargin: 14
      anchors.rightMargin: 14
      spacing: 3
      Label {
        text: card.title
        font.bold: true
      }
      Label {
        width: parent.width
        text: card.description
        wrapMode: Text.WordWrap
        color: root.theme.alpha(root.theme.text, 0.55)
        font.pixelSize: 11
      }
    }

    MouseArea {
      id: cardMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: root.cfg.style = card.key
    }
  }

  // ---- section state -------------------------------------------------------------

  property var collapsed: ({})

  function toggleSection(title) {
    const next = Object.assign({}, collapsed)
    next[title] = !next[title]
    collapsed = next
  }

  function setAllSections(open) {
    const next = {}
    if (!open) for (const t of sectionTitles) next[t] = true
    collapsed = next
  }

  readonly property var sectionTitles: ["Design", "Dock", "Behaviour", "Glass", "Window previews", "Alt+Tab switcher", "Pinned apps"]

  // ---- monitors helper ------------------------------------------------------------

  // [] means "every monitor". Picking every monitor explicitly collapses back to [].
  function toggleMonitor(name) {
    cfg.monitors = SettingsLogic.toggleMonitor(cfg.monitors, Quickshell.screens.map(s => s.name), name)
  }

  function monitorShown(name) {
    return SettingsLogic.monitorShown(cfg.monitors, name)
  }

  // ---- window ---------------------------------------------------------------------

  Item {
    id: keyRoot
    anchors.fill: parent
    focus: true
    Keys.onEscapePressed: root.close()
  }

  Surface {
    anchors.fill: parent
    theme: root.theme
    radius: root.theme.r(26)
    tint: root.theme.panel
  }

  // Header
  Item {
    id: header
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    height: 72

    Column {
      anchors.left: parent.left
      anchors.leftMargin: 24
      anchors.verticalCenter: parent.verticalCenter
      spacing: 2
      Label {
        text: "Dock Settings"
        font.pixelSize: 18
        font.bold: true
      }
      Label {
        text: "Glass Dock " + (root.dock.manifest && root.dock.manifest.version ? "v" + root.dock.manifest.version : "")
          + "  ·  changes apply instantly"
        color: root.theme.alpha(root.theme.text, 0.5)
        font.pixelSize: 11
      }
    }

    Row {
      anchors.right: parent.right
      anchors.rightMargin: 20
      anchors.verticalCenter: parent.verticalCenter
      spacing: 8

      Button {
        readonly property bool anyOpen: root.sectionTitles.some(t => !root.collapsed[t])
        anchors.verticalCenter: parent.verticalCenter
        text: anyOpen ? "Collapse all" : "Expand all"
        onClicked: root.setAllSections(!anyOpen)
      }
      IconButton {
        anchors.verticalCenter: parent.verticalCenter
        glyph: "✕"
        onClicked: root.close()
      }
    }

    Rectangle {
      anchors.bottom: parent.bottom
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.leftMargin: 16
      anchors.rightMargin: 16
      height: 1
      color: root.theme.rimSoft
    }
  }

  Flickable {
    id: scroller
    anchors.top: header.bottom
    anchors.bottom: footer.top
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.leftMargin: 12
    anchors.rightMargin: 12
    clip: true
    contentWidth: width
    contentHeight: body.implicitHeight + 16
    boundsBehavior: Flickable.StopAtBounds

    Column {
      id: body
      width: scroller.width
      spacing: 6

      // -- Design ----------------------------------------------------------------
      Section {
        title: "Design"

        Item {
          width: parent.width
          height: styleCards.height + 8
          Row {
            id: styleCards
            x: 6
            width: parent.width - 12
            spacing: 10
            StyleCard {
              key: "glass"
              title: "Glass"
              description: "Frosted, translucent and rounded, with a soft shine."
            }
            StyleCard {
              key: "omarchy"
              title: "Omarchy"
              description: "Matches your bar: theme colours, borders and window rounding."
            }
          }
        }
      }

      // -- Dock ------------------------------------------------------------------
      Section {
        title: "Dock"

        Setting {
          label: "Show the dock"
          hint: "Remembered after restarts. The key below flips it too"
          Switch { checked: root.cfg.showDock; onToggled: v => root.cfg.showDock = v }
        }
        Setting {
          label: "Show/hide key"
          hint: root.dock.toggleKey.error
            ? "Hyprland refused it: " + root.dock.toggleKey.error
            : "Click, then press the combination. ✕ removes the bind"
          Row {
            spacing: 6
            KeyRecorder { combo: root.cfg.toggleKey; onRecorded: c => root.cfg.toggleKey = c }
            IconButton {
              anchors.verticalCenter: parent.verticalCenter
              glyph: "✕"
              enabledState: root.cfg.toggleKey !== ""
              onClicked: root.cfg.toggleKey = ""
            }
          }
        }
        Setting {
          label: "Icon size"
          Slider { from: 32; to: 96; stepSize: 2; value: root.cfg.iconSize; suffix: " px"; onMoved: v => root.cfg.iconSize = v }
        }
        Setting {
          label: "Magnification"
          hint: "1.00 turns hover zoom off"
          Slider {
            from: 1
            to: 2.2
            stepSize: 0.05
            decimals: 2
            value: root.cfg.magnification
            suffix: "×"
            onMoved: v => root.cfg.magnification = v
          }
        }
        Setting {
          label: "Magnification reach"
          hint: "How many neighbouring icons grow"
          Slider { from: 1; to: 6; stepSize: 1; value: root.cfg.magnificationRange; onMoved: v => root.cfg.magnificationRange = v }
        }
        Setting {
          label: "Distance from edge"
          Slider { from: 0; to: 48; stepSize: 1; value: root.cfg.margin; suffix: " px"; onMoved: v => root.cfg.margin = v }
        }
        Setting {
          label: "Separator before running apps"
          Switch { checked: root.cfg.showRunningSeparator; onToggled: v => root.cfg.showRunningSeparator = v }
        }
        Setting {
          label: "Window dots per app"
          Slider { from: 1; to: 6; stepSize: 1; value: root.cfg.maxDots; onMoved: v => root.cfg.maxDots = v }
        }
        Setting {
          label: "Show on monitors"
          hint: "Click a monitor to show or hide the dock there"
          Row {
            spacing: 6
            Repeater {
              model: Quickshell.screens
              Chip {
                required property var modelData
                text: modelData.name
                selected: root.monitorShown(modelData.name)
                onClicked: root.toggleMonitor(modelData.name)
              }
            }
          }
        }
      }

      // -- Behaviour ---------------------------------------------------------------
      Section {
        title: "Behaviour"

        Setting {
          label: "Show on hover"
          hint: "Hidden until the pointer comes near the dock"
          Switch { checked: root.cfg.showOnHover; onToggled: v => root.cfg.showOnHover = v }
        }
        Setting {
          label: "Reveal area"
          hint: "Distance above the dock; six times that to each side"
          opacity: root.cfg.showOnHover ? 1 : 0.4
          Slider { from: 0; to: 120; stepSize: 4; value: root.cfg.revealArea; suffix: " px"; onMoved: v => root.cfg.revealArea = v }
        }
        Setting {
          label: "Show delay"
          hint: "How long the pointer must stay near the dock first"
          opacity: root.cfg.showOnHover ? 1 : 0.4
          Slider { from: 0; to: 1000; stepSize: 10; value: root.cfg.showDelay; suffix: " ms"; onMoved: v => root.cfg.showDelay = v }
        }
        Setting {
          label: "Hide delay"
          opacity: root.cfg.showOnHover ? 1 : 0.4
          Slider { from: 100; to: 3000; stepSize: 50; value: root.cfg.hideDelay; suffix: " ms"; onMoved: v => root.cfg.hideDelay = v }
        }
        Setting {
          label: "Animations"
          hint: "Off makes everything instant and is the lightest on the GPU"
          Switch { checked: root.cfg.animations; onToggled: v => root.cfg.animations = v }
        }
        Setting {
          label: "Act as overlay"
          hint: "Float over open windows instead of reserving space for the dock"
          Switch { checked: root.cfg.overlay; onToggled: v => root.cfg.overlay = v }
        }
      }

      // -- Glass -------------------------------------------------------------------
      Section {
        title: "Glass"
        visible: root.theme.glass

        Setting {
          label: "Tint"
          hint: "Lower is more see-through"
          // Below ~0.15 Hyprland's blur threshold (ignore_alpha 0.12) would drop the blur.
          Slider { from: 0.15; to: 0.9; stepSize: 0.01; decimals: 2; value: root.cfg.glassOpacity; onMoved: v => root.cfg.glassOpacity = v }
        }
        Setting {
          label: "Shine"
          Slider {
            from: 0
            to: 0.4
            stepSize: 0.01
            decimals: 2
            value: root.cfg.glassHighlight
            onMoved: v => root.cfg.glassHighlight = v
          }
        }
        Setting {
          label: "Corner radius"
          Slider { from: 0; to: 40; stepSize: 1; value: root.cfg.cornerRadius; suffix: " px"; onMoved: v => root.cfg.cornerRadius = v }
        }
      }

      // -- Window groups -------------------------------------------------------------
      Section {
        title: "Window previews"

        Setting {
          label: "Show previews on hover"
          Switch { checked: root.cfg.previews; onToggled: v => root.cfg.previews = v }
        }
        Setting {
          label: "Preview size"
          opacity: root.cfg.previews ? 1 : 0.4
          Slider { from: 160; to: 400; stepSize: 10; value: root.cfg.previewWidth; suffix: " px"; onMoved: v => root.cfg.previewWidth = v }
        }
        Setting {
          label: "Hover delay"
          opacity: root.cfg.previews ? 1 : 0.4
          Slider { from: 0; to: 1200; stepSize: 20; value: root.cfg.previewDelay; suffix: " ms"; onMoved: v => root.cfg.previewDelay = v }
        }
      }

      // -- Switcher ------------------------------------------------------------------
      Section {
        title: "Alt+Tab switcher"

        Setting {
          label: "Use Glass Dock for Alt+Tab"
          hint: "Off falls back to Omarchy's plain window cycling"
          Switch { checked: root.cfg.switcher; onToggled: v => root.cfg.switcher = v }
        }
        Setting {
          label: "Show on"
          hint: "Which display the switcher appears on"
          Row {
            spacing: 6
            Repeater {
              model: [
                { key: "focused", label: "Current display" },
                { key: "primary", label: "Main display" },
                { key: "all", label: "All displays" }
              ]
              Chip {
                required property var modelData
                text: modelData.label
                selected: (root.cfg.switcherDisplay || "focused") === modelData.key
                onClicked: root.cfg.switcherDisplay = modelData.key
              }
            }
          }
        }
        Setting {
          label: "Main display"
          hint: root.cfg.switcherMainDisplay ? "Used by \"Main display\"" : "Not set: the first display is used"
          opacity: root.cfg.switcherDisplay === "primary" ? 1 : 0.4
          Row {
            spacing: 6
            Repeater {
              model: Quickshell.screens
              Chip {
                required property var modelData
                text: modelData.name
                selected: root.cfg.switcherMainDisplay === modelData.name
                  || (!root.cfg.switcherMainDisplay && index === 0)
                required property int index
                onClicked: root.cfg.switcherMainDisplay = modelData.name
              }
            }
          }
        }
        Setting {
          label: "Current workspace only"
          Switch { checked: root.cfg.switcherCurrentWorkspaceOnly; onToggled: v => root.cfg.switcherCurrentWorkspaceOnly = v }
        }
        Setting {
          label: "Card size"
          Slider {
            from: 200
            to: 420
            stepSize: 10
            value: root.cfg.switcherCardWidth
            suffix: " px"
            onMoved: v => root.cfg.switcherCardWidth = v
          }
        }
        Setting {
          label: "Overlay delay"
          hint: "Quicker taps switch without showing the overlay"
          Slider {
            from: 0
            to: 400
            stepSize: 10
            value: root.cfg.switcherRevealDelay
            suffix: " ms"
            onMoved: v => root.cfg.switcherRevealDelay = v
          }
        }
      }

      // -- Pinned apps -----------------------------------------------------------------
      Section {
        title: "Pinned apps"

        Label {
          visible: root.cfg.pinned.length === 0
          leftPadding: 12
          text: "Nothing pinned yet. Right-click an app in the dock and choose Keep in Dock."
          color: root.theme.alpha(root.theme.text, 0.55)
          font.pixelSize: 12
        }

        Repeater {
          model: root.cfg.pinned
          Setting {
            required property string modelData
            required property int index
            label: root.dock.apps.nameFor(modelData)
            hint: modelData

            Row {
              spacing: 2
              Image {
                anchors.verticalCenter: parent.verticalCenter
                width: 24
                height: 24
                sourceSize: Qt.size(48, 48)
                source: root.dock.apps.iconFor(modelData)
              }
              Item { width: 8; height: 1 }
              IconButton {
                glyph: "↑"
                enabledState: index > 0
                onClicked: root.settings.movePinned(modelData, index - 1)
              }
              IconButton {
                glyph: "↓"
                enabledState: index < root.cfg.pinned.length - 1
                onClicked: root.settings.movePinned(modelData, index + 1)
              }
              IconButton {
                glyph: "✕"
                destructive: true
                onClicked: root.settings.togglePin(modelData)
              }
            }
          }
        }
      }
    }
  }

  // Footer
  Item {
    id: footer
    anchors.bottom: parent.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    height: 64

    Rectangle {
      anchors.top: parent.top
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.leftMargin: 16
      anchors.rightMargin: 16
      height: 1
      color: root.theme.rimSoft
    }

    Row {
      anchors.left: parent.left
      anchors.leftMargin: 20
      anchors.verticalCenter: parent.verticalCenter
      spacing: 8
      Button {
        text: "Reset to defaults"
        destructive: true
        onClicked: root.settings.resetToDefaults()
      }
      Button {
        text: "Edit JSON"
        onClicked: Quickshell.execDetached(["xdg-open", root.settings.path])
      }
    }

    Button {
      anchors.right: parent.right
      anchors.rightMargin: 20
      anchors.verticalCenter: parent.verticalCenter
      text: "Done"
      onClicked: root.close()
    }
  }
}
