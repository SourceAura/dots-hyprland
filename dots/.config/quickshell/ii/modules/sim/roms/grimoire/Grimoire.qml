/* Grimoire.qml — Code Editor ROM (dots-hyprland port) */
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../../../../services/sim" as SiM

Item {
    id: root
    anchors.fill: parent

    property color morphColor: SiM.SiMSovereign.prismaticColor
    property var   ctrl:       null

    RowLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 12

        // ── Code Editor Surface ──
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 8
            color: Qt.rgba(0.05, 0.05, 0.08, 0.8)
            border.color: Qt.rgba(1, 1, 1, 0.1)

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Text {
                        text: "GRIMOIRE EDITOR"
                        color: Qt.rgba(1, 1, 1, 0.5)
                        font.family: SiM.TransparentWorld.fontFamilyMono
                        font.pixelSize: 10
                        font.bold: true
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: "UTF-8"
                        color: Qt.rgba(1, 1, 1, 0.3)
                        font.family: SiM.TransparentWorld.fontFamilyMono
                        font.pixelSize: 8
                    }
                }

                // §15: ScrollView is acceptable here — it's a fixed-size editor, not dynamic data
                ScrollView {
                    Layout.fillHeight: true
                    Layout.fillWidth: true
                    clip: true

                    TextArea {
                        id: _editorArea
                        text: "// Write your intentions here...\n// SiM is watching the lines.\n\nfunction ignite() {\n    console.log('The Forge is hot.');\n}"
                        color: Qt.rgba(root.morphColor.r, root.morphColor.g, root.morphColor.b, 0.9)
                        font.family: SiM.TransparentWorld.fontFamilyMono
                        font.pixelSize: 14
                        wrapMode: TextArea.NoWrap
                        background: null
                        selectByMouse: true
                    }
                }
            }
        }

        // ── SiM Co-Pilot panel ──
        Rectangle {
            Layout.preferredWidth: 280
            Layout.fillHeight: true
            radius: 8
            color: Qt.rgba(0, 0, 0, 0.4)
            border.color: Qt.rgba(root.morphColor.r, root.morphColor.g, root.morphColor.b, 0.2)

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 10

                Text {
                    text: "◈ SiM CO-PILOT"
                    color: root.morphColor
                    font.family: SiM.TransparentWorld.fontFamilyMono
                    font.pixelSize: 10
                    font.bold: true
                }

                // §15: ListView for dynamic response content
                ListView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: false
                    boundsBehavior: Flickable.StopAtBounds
                    model: SiM.SiMSovereign.simMessages.length > 0
                           ? [SiM.SiMSovereign.simMessages[SiM.SiMSovereign.simMessages.length - 1]]
                           : []

                    delegate: Text {
                        required property var modelData
                        width: parent ? parent.width : 0
                        text: modelData.text || "Awaiting directive..."
                        color: "white"
                        font.family: SiM.TransparentWorld.fontFamilyMono
                        font.pixelSize: 12
                        wrapMode: Text.WordWrap
                        opacity: modelData.text ? 1.0 : 0.4
                    }

                    // Empty state
                    Text {
                        anchors.fill: parent
                        anchors.margins: 8
                        visible: SiM.SiMSovereign.simMessages.length === 0
                        text: "Awaiting directive..."
                        color: Qt.rgba(1, 1, 1, 0.25)
                        font.family: SiM.TransparentWorld.fontFamilyMono
                        font.pixelSize: 12
                        font.italic: true
                        wrapMode: Text.WordWrap
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 30
                    radius: 4
                    color: Qt.rgba(1, 1, 1, 0.05)

                    Text {
                        anchors.centerIn: parent
                        text: "Ask SiM to refactor…"
                        color: Qt.rgba(1, 1, 1, 0.2)
                        font.family: SiM.TransparentWorld.fontFamilyMono
                        font.pixelSize: 9
                    }
                }
            }
        }
    }
}
