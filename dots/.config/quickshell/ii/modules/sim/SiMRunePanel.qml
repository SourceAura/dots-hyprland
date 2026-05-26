/* SiMRunePanel.qml — Active fold rune chips
 * ==================================================================
 * DESTINATION: .config/quickshell/modules/sim/SiMRunePanel.qml
 *
 * Horizontal scrolling row of rune chips for the active fold.
 * Tapping a chip stages it as a locked token in SiMCommandBar.
 *
 * Ported from: soul/obelisk/runes/RuneChip.qml + RuneRegistry.qml
 * Simplified — no SDF shader (that requires the compiled .qsb files
 * from the DMS plugin). Uses a clean glass pill style instead.
 * The full shader version is available when the shaders/ dir is copied.
 *
 * §14.9: TapHandler + HoverHandler only
 */
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "../../services/sim" as SiM

Item {
    id: root

    implicitHeight: 36

    // ── Active fold filter ────────────────────────────────────────────
    // Shows runes for the current breathing style's primary fold:
    //   celestial → all folds (show eye + blade)
    //   moon      → eye fold (recon only)
    //   sun       → blade fold (offensive)
    readonly property string _activeFold: {
        var s = SiM.SiMSovereign.breathingStyle
        if (s === "moon") return "eye"
        if (s === "sun")  return "blade"
        return "eye"   // celestial default — show recon
    }

    readonly property var _runes: SiM.SiMRunes.byFold(_activeFold)

    signal runeSelected(var rune)

    // ── Scroll container ──────────────────────────────────────────────
    Item {
        anchors.fill: parent
        clip: false

        // §15: ListView for scrollable content
        ListView {
            id: _list
            anchors.fill: parent
            orientation: ListView.Horizontal
            spacing: 6
            clip: false
            boundsBehavior: Flickable.StopAtBounds
            model: root._runes

            delegate: Rectangle {
                id: _chip
                required property var  modelData
                required property int  index

                readonly property color _c: Qt.color(modelData.color || "#00B4D8")

                width:  _chipRow.implicitWidth + 18
                height: 28
                radius: 14

                color: _hov.hovered
                    ? Qt.rgba(_c.r, _c.g, _c.b, 0.15)
                    : Qt.rgba(_c.r, _c.g, _c.b, 0.07)
                border.color: Qt.rgba(_c.r, _c.g, _c.b, _hov.hovered ? 0.55 : 0.28)
                border.width: 1

                Behavior on color        { ColorAnimation { duration: 120 } }
                Behavior on border.color { ColorAnimation { duration: 120 } }

                Row {
                    id: _chipRow
                    anchors.centerIn: parent
                    spacing: 5

                    Text {
                        text:  _chip.modelData.icon || "◈"
                        color: _chip._c
                        font.pixelSize: 12
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text:  _chip.modelData.label || ""
                        color: Qt.rgba(1, 1, 1, 0.80)
                        font.family:    "3270 Nerd Font Mono, Fira Code, monospace"
                        font.pixelSize: 11
                        font.bold:      true
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                TapHandler {
                    onTapped: root.runeSelected(_chip.modelData)
                }
                HoverHandler { id: _hov }
            }
        }
    }
}
