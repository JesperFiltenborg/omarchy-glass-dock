import QtQuick
import qs.Commons
import qs.Ui as OmarchyUi

// The pane every dock surface is drawn on, in the design chosen in settings.
//
// Glass: translucent tint (Hyprland blurs what is behind it through the
// `glassdock*` layer rule), a specular sheen fading down from the top edge, a
// bright rim and a faint inner rim for thickness.
//
// Omarchy: the shell's own BorderSurface with the theme's popup border spec,
// the same component the bar's popups are drawn with.
Item {
  id: root

  required property var theme
  property real radius: theme.radius
  property color tint: theme.tint
  property color rim: theme.rim
  property real highlight: theme.highlight

  // ---- Omarchy -----------------------------------------------------------------

  Loader {
    anchors.fill: parent
    active: !root.theme.glass
    sourceComponent: OmarchyUi.BorderSurface {
      color: root.tint
      radius: root.radius
      borderSpec: Border.localOrSurfaceSpec("popups", "border", Color.popups.border,
        Color.popups.border, root.theme.rimWidth)
    }
  }

  // ---- Glass -----------------------------------------------------------------------

  Item {
    anchors.fill: parent
    visible: root.theme.glass

    Rectangle {
      anchors.fill: parent
      radius: root.radius
      color: root.tint
    }

    // Sheen: strongest at the top edge, gone by the middle.
    Rectangle {
      anchors.fill: parent
      radius: root.radius
      gradient: Gradient {
        GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, root.highlight) }
        GradientStop { position: 0.35; color: Qt.rgba(1, 1, 1, root.highlight * 0.3) }
        GradientStop { position: 0.6; color: Qt.rgba(1, 1, 1, 0) }
        GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, root.highlight * 0.12) }
      }
    }

    // Specular line where light catches the top edge.
    Rectangle {
      anchors.top: parent.top
      anchors.topMargin: 1
      anchors.horizontalCenter: parent.horizontalCenter
      width: Math.max(0, parent.width - root.radius * 2)
      height: 1
      gradient: Gradient {
        orientation: Gradient.Horizontal
        GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0) }
        GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, Math.min(1, root.highlight * 3)) }
        GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0) }
      }
    }

    Rectangle {
      anchors.fill: parent
      radius: root.radius
      color: "transparent"
      border.width: 1
      border.color: root.rim
    }

    Rectangle {
      anchors.fill: parent
      anchors.margins: 1
      radius: Math.max(0, root.radius - 1)
      color: "transparent"
      border.width: 1
      border.color: root.theme.rimSoft
    }
  }
}
