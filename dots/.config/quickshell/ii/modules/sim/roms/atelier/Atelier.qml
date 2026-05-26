/* Atelier.qml — Workshop ROM (dots-hyprland port)
 * FORGE fold — ⬡ #FF6B35
 * Tabs: SIBYLS · ABYSS (Docker) · LAPIDARY (Vault)
 */
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import "../../../../services/sim" as SiM
import "../../../../services/sim/Sibyls.js" as SibylData

Item {
    id: root
    anchors.fill: parent

    property color morphColor: SiM.SiMSovereign.prismaticColor
    property var   ctrl:       null

    property int _tab: 0
    readonly property var _tabs: [
        { id: 0, label: "SIBYLS",   glyph: "◈" },
        { id: 1, label: "ABYSS",    glyph: "🐳" },
        { id: 2, label: "LAPIDARY", glyph: "⊛" }
    ]

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 12

        // ── Header & Tabs ──
        RowLayout {
            Layout.fillWidth: true
            height: 32
            spacing: 16

            Text {
                text: "工房 ATELIER"
                color: root.morphColor
                font.family: SiM.TransparentWorld.fontFamilyMono
                font.pixelSize: 14
                font.bold: true
                font.letterSpacing: 2
            }

            Row {
                spacing: 4
                Repeater {
                    model: root._tabs
                    delegate: Rectangle {
                        required property var modelData
                        required property int index
                        width: _tabTxt.implicitWidth + 20
                        height: 26; radius: 6
                        color: root._tab === modelData.id
                               ? Qt.rgba(root.morphColor.r, root.morphColor.g, root.morphColor.b, 0.15)
                               : "transparent"
                        border.color: root._tab === modelData.id
                                      ? root.morphColor : Qt.rgba(1,1,1,0.1)

                        Text {
                            id: _tabTxt
                            anchors.centerIn: parent
                            text: modelData.glyph + " " + modelData.label
                            color: root._tab === modelData.id ? "white" : Qt.rgba(1,1,1,0.4)
                            font.family: SiM.TransparentWorld.fontFamilyMono
                            font.pixelSize: 10
                            font.bold: root._tab === modelData.id
                        }

                        TapHandler { onTapped: root._tab = modelData.id }
                    }
                }
            }

            Item { Layout.fillWidth: true }
        }

        // ── Content ──
        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: root._tab

            // Tab 0: SIBYLS
            ColumnLayout {
                spacing: 10

                Rectangle {
                    Layout.fillWidth: true
                    height: 50; radius: 8
                    color: Qt.rgba(0,0,0,0.3)
                    border.color: Qt.rgba(1,1,1,0.05)

                    Row {
                        anchors.centerIn: parent
                        spacing: 8
                        Repeater {
                            model: SibylData.Sibyls
                            delegate: Rectangle {
                                required property var modelData
                                width: 36; height: 36; radius: 18
                                color: Qt.rgba(Qt.color(modelData.accent).r, Qt.color(modelData.accent).g, Qt.color(modelData.accent).b, 0.1)
                                border.color: Qt.rgba(Qt.color(modelData.accent).r, Qt.color(modelData.accent).g, Qt.color(modelData.accent).b, 0.4)
                                border.width: 1
                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.icon
                                    color: modelData.accent
                                    font.pixelSize: 16
                                }
                                HoverHandler { id: _sibylHov }
                                ToolTip.visible: _sibylHov.hovered
                                ToolTip.text: modelData.name + " — " + modelData.desc
                            }
                        }
                    }
                }

                GridLayout {
                    Layout.fillWidth: true
                    columns: 2
                    rowSpacing: 10
                    columnSpacing: 10

                    Repeater {
                        model: SibylData.Sibyls
                        delegate: Rectangle {
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.preferredHeight: 100
                            radius: 10
                            color: Qt.rgba(1,1,1,0.03)
                            border.color: Qt.rgba(Qt.color(modelData.accent).r, Qt.color(modelData.accent).g, Qt.color(modelData.accent).b, 0.2)

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 12

                                Rectangle {
                                    width: 48; height: 48; radius: 24
                                    color: Qt.rgba(Qt.color(modelData.accent).r, Qt.color(modelData.accent).g, Qt.color(modelData.accent).b, 0.1)
                                    Text { anchors.centerIn: parent; text: modelData.icon; color: modelData.accent; font.pixelSize: 24 }
                                }

                                ColumnLayout {
                                    spacing: 2
                                    Text { text: modelData.name.toUpperCase(); color: "white"; font.family: SiM.TransparentWorld.fontFamilyMono; font.pixelSize: 12; font.bold: true }
                                    Text { text: modelData.desc; color: Qt.rgba(1,1,1,0.4); font.family: SiM.TransparentWorld.fontFamilyMono; font.pixelSize: 9 }
                                    Text { text: "Principle: " + modelData.principle; color: modelData.accent; font.family: SiM.TransparentWorld.fontFamilyMono; font.pixelSize: 8; font.bold: true }
                                }

                                Item { Layout.fillWidth: true }

                                ColumnLayout {
                                    spacing: 4
                                    Text { text: "CONFIDENCE"; color: Qt.rgba(1,1,1,0.3); font.family: SiM.TransparentWorld.fontFamilyMono; font.pixelSize: 8; Layout.alignment: Qt.AlignRight }
                                    Rectangle {
                                        width: 80; height: 4; radius: 2
                                        color: Qt.rgba(1,1,1,0.05)
                                        Rectangle { width: parent.width * 0.85; height: parent.height; radius: 2; color: modelData.accent }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Tab 1: ABYSS
            AtelierAbyss {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: root._tab === 1
            }

            // Tab 2: LAPIDARY
            AtelierLapidary {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: root._tab === 2
            }
        }

        AtelierSiMStrip {
            Layout.fillWidth: true
            accent: root.morphColor
        }
    }
}
