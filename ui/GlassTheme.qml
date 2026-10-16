import QtQuick
import qs.Commons

// Visual tokens for every glass surface, derived from the active Omarchy theme
// so the dock follows `omarchy theme set` without a restart.
QtObject {
  id: theme

  required property var settings

  readonly property color base: Color.background
  readonly property color text: Color.foreground
  readonly property color accent: Color.accent
  readonly property color urgent: Color.urgent
  readonly property color muted: Color.muted

  readonly property real tintAlpha: settings.cfg.glassOpacity
  readonly property real highlight: settings.cfg.glassHighlight
  readonly property int radius: settings.cfg.cornerRadius

  readonly property color tint: Qt.rgba(base.r, base.g, base.b, tintAlpha)
  readonly property color tintStrong: Qt.rgba(base.r, base.g, base.b, Math.min(0.85, tintAlpha + 0.25))
  readonly property color rim: Qt.rgba(1, 1, 1, 0.20)
  readonly property color rimSoft: Qt.rgba(1, 1, 1, 0.07)
  readonly property color hoverFill: Qt.rgba(1, 1, 1, 0.10)
  readonly property color selectedFill: Qt.rgba(accent.r, accent.g, accent.b, 0.22)
  readonly property color selectedRim: Qt.rgba(accent.r, accent.g, accent.b, 0.85)

  readonly property string fontFamily: Style.fontFamily
  readonly property int fontSize: 13

  function alpha(c, a) {
    return Qt.rgba(c.r, c.g, c.b, a)
  }
}
