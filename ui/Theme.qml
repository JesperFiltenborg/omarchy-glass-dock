import QtQuick
import qs.Commons

// Visual tokens for every surface, derived from the active Omarchy theme so the
// dock follows `omarchy theme set` without a restart.
//
// Two designs, picked with settings.cfg.style:
//   "glass"    translucent tint over Hyprland blur, sheen, bright rim, rounded
//   "omarchy"  Omarchy's own style guide: solid bar/popup colours, the theme's
//              popup border, Hyprland's corner rounding and the shell's
//              hover/selection fills, exactly as the bar and its panels use them
QtObject {
  id: theme

  required property var settings

  readonly property bool glass: settings.cfg.style !== "omarchy"
  // Off: every Behavior and the launch bounce are disabled, so changes are instant.
  readonly property bool animate: settings.cfg.animations

  readonly property color base: Color.background
  readonly property color text: Color.foreground
  readonly property color accent: Color.accent
  readonly property color urgent: Color.urgent
  readonly property color muted: Color.muted

  // Glass-only knobs; zeroed for the Omarchy design.
  readonly property real tintAlpha: glass ? settings.cfg.glassOpacity : 1
  readonly property real highlight: glass ? settings.cfg.glassHighlight : 0

  // Corner radius of the shelf. Omarchy mirrors Hyprland's decoration:rounding.
  readonly property int radius: glass ? settings.cfg.cornerRadius : Style.cornerRadius

  // Radius for any other rounded element: the designed value in glass, capped
  // to Hyprland's rounding in the Omarchy design (0 there means square).
  function r(designed) {
    return glass ? designed : Math.min(designed, Style.cornerRadius)
  }

  // Shelf background (the dock itself) and raised surfaces (popups, menus, switcher).
  readonly property color tint: glass ? alpha(base, tintAlpha) : Color.bar.background
  readonly property color tintStrong: glass ? alpha(base, Math.min(0.85, tintAlpha + 0.25)) : Color.popups.background
  readonly property color panel: glass ? alpha(base, Math.max(0.78, tintAlpha)) : Color.popups.background

  readonly property color rim: glass ? Qt.rgba(1, 1, 1, 0.20) : Color.popups.border
  readonly property color rimSoft: glass ? Qt.rgba(1, 1, 1, 0.07) : alpha(text, 0.14)
  readonly property int rimWidth: glass ? 1 : Math.max(1, Style.space(2))

  readonly property color hoverFill: glass ? Qt.rgba(1, 1, 1, 0.10) : Style.hoverFill
  readonly property color selectedFill: glass ? alpha(accent, 0.22) : Style.selectedFill
  readonly property color selectedRim: glass ? alpha(accent, 0.85) : accent

  // Controls (settings window), mirroring qs.Ui ToggleSwitch / PanelSlider.
  function switchTrack(on) {
    return glass ? (on ? accent : alpha(text, 0.14))
      : (on ? Style.selectedFillFor(text, accent) : Style.normalFillFor(text, accent))
  }
  function switchKnob(on) {
    return glass ? "white" : (on ? Style.selectedStateColor(text, accent) : Qt.darker(text, 1.25))
  }
  readonly property color sliderTrack: glass ? alpha(text, 0.14) : Style.selectedFillFor(text, accent)
  readonly property color sliderFill: glass ? accent : text
  readonly property color sliderKnob: glass ? "white" : text

  readonly property string fontFamily: Style.fontFamily
  readonly property int fontSize: 13

  function alpha(c, a) {
    return Qt.rgba(c.r, c.g, c.b, a)
  }
}
