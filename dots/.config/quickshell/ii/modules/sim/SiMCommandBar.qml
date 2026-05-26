/* SiMCommandBar.qml — NLU-powered command input for the SiM tab
 * ==================================================================
 * DESTINATION: .config/quickshell/modules/sim/SiMCommandBar.qml
 *
 * Ported from: soul/obelisk/runes/InputLens.qml (DMS plugin)
 * Simplified for sidebar integration — no ember particles, no
 * full-screen shader overlay. Core NLU + ghost text + rune chips.
 *
 * Wiring in end4's sidebar tab:
 *   SiMCommandBar {
 *       width: parent.width
 *       onCommandExecuted: function(cmd, intent) { ... }
 *   }
 *
 * §14.9: TapHandler + HoverHandler only (no new MouseArea)
 * §16:   visible on stable gate; opacity on data condition
 */
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import "../../services/sim" as SiM

Rectangle {
    id: root

    // ── Public API ────────────────────────────────────────────────────
    property string query:     ""
    property color  morphColor: SiM.SiMSovereign.prismaticColor
    property var    lockedTokens: []

    signal commandExecuted(string cmd, var intent)
    signal tokenLocked(var token)
    signal closeRequested()

    // ── Geometry ──────────────────────────────────────────────────────
    implicitHeight: 44
    radius: 22
    color: Qt.rgba(0.04, 0.06, 0.11, 0.82)
    border.color: Qt.rgba(morphColor.r, morphColor.g, morphColor.b,
                          _input.activeFocus ? 0.55 : 0.22)
    border.width: 1

    Behavior on border.color { ColorAnimation { duration: 120 } }
    Behavior on morphColor   { ColorAnimation { duration: 300 } }

    // Top shimmer line
    Rectangle {
        anchors { top: parent.top; left: parent.left; right: parent.right; margins: 1 }
        height: 1; radius: parent.radius
        color: Qt.rgba(1, 1, 1, 0.055)
    }

    // Shadow
    layer.enabled: _input.activeFocus
    layer.effect: MultiEffect {
        shadowEnabled: true
        shadowColor:   Qt.rgba(root.morphColor.r, root.morphColor.g, root.morphColor.b, 0.35)
        shadowBlur:    0.8
        shadowVerticalOffset: 4
        blurEnabled:   false
    }

    // ── Layout ────────────────────────────────────────────────────────
    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        spacing: 10

        // Leading sigil — breathing style icon
        Text {
            text: {
                var s = SiM.SiMSovereign.breathingStyle
                if (s === "sun")       return "☀"
                if (s === "moon")      return "☽"
                return "◈"
            }
            color: root.morphColor
            font.pixelSize: 16
            Layout.alignment: Qt.AlignVCenter
            Behavior on color { ColorAnimation { duration: 300 } }
        }

        // Input area
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            // Placeholder
            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: _input.text.length === 0 && root.lockedTokens.length === 0
                text: "∿  speak or command"
                color: Qt.rgba(1, 1, 1, 0.18)
                font.family:    "3270 Nerd Font Mono, Fira Code, monospace"
                font.pixelSize: 14
                font.italic:    true
            }

            // Ghost text suffix
            Text {
                id: _ghost
                anchors.verticalCenter: parent.verticalCenter
                x: _input.cursorRectangle.x + _input.cursorRectangle.width
                visible: _ghostStr !== "" && _input.text.length > 0
                text: _ghostStr
                color: Qt.rgba(root.morphColor.r, root.morphColor.g, root.morphColor.b, 0.35)
                font.family:    "3270 Nerd Font Mono, Fira Code, monospace"
                font.pixelSize: 14
                font.italic:    true

                readonly property string _ghostStr: SiM.SiMNLU.ghostText(_input.text)
            }

            // Actual input
            TextInput {
                id: _input
                anchors.fill: parent
                color: "#ffffffe6"
                font.family:    "3270 Nerd Font Mono, Fira Code, monospace"
                font.pixelSize: 14
                verticalAlignment: TextInput.AlignVCenter
                selectByMouse: true
                clip: false

                onTextChanged: {
                    root.query = text
                    SiM.SiMSovereign.recordKeystroke()
                }

                Keys.onReturnPressed: function(event) {
                    _execute()
                    event.accepted = true
                }
                Keys.onEscapePressed: function(event) {
                    root.closeRequested()
                    event.accepted = true
                }
                Keys.onTabPressed: function(event) {
                    // Accept ghost text completion
                    var ghost = SiM.SiMNLU.ghostText(text)
                    if (ghost !== "") {
                        text = text + ghost
                        cursorPosition = text.length
                    }
                    event.accepted = true
                }
            }
        }

        // Clear button — visible when there's input
        Rectangle {
            width: 20; height: 20; radius: 10
            visible: root.query.length > 0
            color: _clearHov.hovered ? Qt.rgba(1, 0, 0, 0.15) : "transparent"

            Text {
                anchors.centerIn: parent
                text: "✕"
                color: Qt.rgba(1, 1, 1, 0.35)
                font.pixelSize: 10
            }

            TapHandler { onTapped: { _input.text = ""; root.query = "" } }
            HoverHandler { id: _clearHov }
        }
    }

    // ── Execute ───────────────────────────────────────────────────────
    function _execute() {
        var cmd = root.query.trim()
        if (!cmd) return

        // Check sovereign commands first (style transitions, shikai/bankai)
        var sovereignResult = SiM.SiMSovereign.processCommand(cmd)
        if (sovereignResult.handled) {
            _input.text = ""
            root.query = ""
            return
        }

        var intent = SiM.SiMNLU.classify(cmd)
        root.commandExecuted(cmd, intent)
        _input.text = ""
        root.query = ""
    }

    // ── Focus helper ──────────────────────────────────────────────────
    function focusInput() { _input.forceActiveFocus() }
    Component.onCompleted: _input.forceActiveFocus()
}
