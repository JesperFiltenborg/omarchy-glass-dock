import QtQuick

// A pane of liquid glass: translucent tint (Hyprland blurs what is behind it
// through the `glassdock*` layer rule), a specular sheen fading down from the
// top edge, a bright rim and a faint inner rim for thickness.
Item {
  id: root

  required property var theme
  property real radius: theme.radius
  property color tint: theme.tint
  property color rim: theme.rim
  property real highlight: theme.highlight

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
