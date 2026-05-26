/* SiMBreathingMode.qml — Breathing style mode switcher
 * ==================================================================
 * DESTINATION: .config/quickshell/modules/sim/SiMBreathingMode.qml
 *
 * Three-button pill row: Celestial · Moon · Sun
 * Clicking Moon or Celestial transitions immediately.
 * Clicking Sun triggers the shikai → bankai confirmation flow.
 *
 * §14.9: TapHandler + HoverHandler only
 * §16:   visible on stable gate; opacity on data condition
 */
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import "../../services/sim" as SiM

Item {
    id: root

    implicitHeight: 32
    implicitWidth:  _row.implicitWidth

    readonly property var _modes: [
        { id: "celestial", label: "PRISMATIC", icon: "◈", color: "#B44FE8" },
        { id: "moon",      label: "MOON",      icon: "☽", color: "#00B4D8" },
        { id: "sun",       label: "SUN",       icon: "☀", color: "#f43f5e" }
    ]

    Row {
        id: _row
        anchors.fill: parent
        spacing: 4

        Repeater {
            model: root._modes

            delegate: Rectangle {
                id: _btn
                required property var  modelData
                required property int  index

                readonly property bool _isActive: SiM.SiMSovereign.breathingStyle === modelData.id
                readonly property color _c: Qt.color(modelData.color)

                width:  _btnRow.implicitWidth + 20
                height: 28
                radius: 14

                color: _isActive
                    ? Qt.rgba(_c.r, _c.g, _c.b, 0.15)
                    : (_hov.hovered ? Qt.rgba(_c.r, _c.g, _c.b, 0.07) : "transparent")
                border.color: _isActive
                    ? Qt.rgba(_c.r, _c.g, _c.b, 0.55)
                    : Qt.rgba(1, 1, 1, 0.10)
                border.width: 1

                Behavior on color        { ColorAnimation { duration: 150 } }
                Behavior on border.color { ColorAnimation { duration: 150 } }

                layer.enabled: _isActive
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor:   Qt.rgba(_btn._c.r, _btn._c.g, _btn._c.b, 0.40)
                    shadowBlur:    0.75
                    blurEnabled:   false
                }

                Row {
                    id: _btnRow
                    anchors.centerIn: parent
                    spacing: 5

                    Text {
                        text:  _btn.modelData.icon
                        color: _btn._isActive ? _btn._c : Qt.rgba(1, 1, 1, 0.35)
                        font.pixelSize: 13
                        anchors.verticalCenter: parent.verticalCenter
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }
                    Text {
                        text:  _btn.modelData.label
                        color: _btn._isActive ? "#ffffff" : Qt.rgba(1, 1, 1, 0.35)
                        font.family:    "3270 Nerd Font Mono, Fira Code, monospace"
                        font.pixelSize: 10
                        font.bold:      _btn._isActive
                        font.letterSpacing: 1.5
                        anchors.verticalCenter: parent.verticalCenter
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }
                }

                TapHandler {
                    onTapped: {
                        var result = SiM.SiMSovereign.processCommand(_btn.modelData.id)
                        // Sun mode shows confirmation — handled by SiMSovereign
                    }
                }
                HoverHandler { id: _hov }
            }
        }
    }
}
