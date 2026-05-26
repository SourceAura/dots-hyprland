/* Ori.qml — Web Weaver ROM (dots-hyprland port)
 * EYE fold — ◉ #00C2FF
 * Monroe consciousness model: Locale I (clearnet) → II (darknet) → III (IPFS)
 */
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../../../../services/sim" as SiM

Item {
    id: root
    anchors.fill: parent

    property color morphColor: SiM.SiMSovereign.prismaticColor
    property var   ctrl:       null

    property real consciousnessLevel: 0.15

    readonly property int currentLocale: {
        if (consciousnessLevel <= 0.4) return 1
        if (consciousnessLevel <= 0.7) return 2
        return 3
    }

    readonly property string localeSignature: {
        if (currentLocale === 1) return "physical-tangible-immediate"
        if (currentLocale === 2) return "astral-mental-entity-populated"
        return "alternate-physical-dimension"
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 16

        // ── Consciousness Bar ──
        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Text {
                text: "CONSCIOUSNESS"
                color: "white"
                font.family: SiM.TransparentWorld.fontFamilyMono
                font.pixelSize: 9
                font.bold: true
                opacity: 0.6
            }

            Slider {
                id: _slider
                Layout.fillWidth: true
                from: 0.1; to: 1.0
                value: root.consciousnessLevel
                onMoved: root.consciousnessLevel = value

                background: Rectangle {
                    x: _slider.leftPadding
                    y: _slider.topPadding + _slider.availableHeight / 2 - height / 2
                    implicitWidth: 200; implicitHeight: 4
                    width: _slider.availableWidth; height: implicitHeight
                    radius: 2; color: Qt.rgba(1,1,1,0.1)
                    Rectangle {
                        width: _slider.visualPosition * parent.width
                        height: parent.height; radius: 2
                        color: root.morphColor
                    }
                }

                handle: Rectangle {
                    x: _slider.leftPadding + _slider.visualPosition * (_slider.availableWidth - width)
                    y: _slider.topPadding + _slider.availableHeight / 2 - height / 2
                    implicitWidth: 12; implicitHeight: 12; radius: 6
                    color: "white"; border.color: root.morphColor; border.width: 2
                }
            }

            Text {
                text: root.consciousnessLevel.toFixed(2)
                color: root.morphColor
                font.family: SiM.TransparentWorld.fontFamilyMono
                font.pixelSize: 10
            }
        }

        // ── Locale Selector ──
        RowLayout {
            Layout.fillWidth: true
            spacing: 20

            Repeater {
                model: [
                    { id: 1, label: "LOCALE I",   desc: "Clear Net", icon: "🌐" },
                    { id: 2, label: "LOCALE II",  desc: "Dark Net",  icon: "🌑" },
                    { id: 3, label: "LOCALE III", desc: "IPFS",      icon: "📦" }
                ]

                delegate: Rectangle {
                    Layout.preferredWidth: 140; Layout.preferredHeight: 50
                    radius: 6
                    color: root.currentLocale === modelData.id
                           ? Qt.rgba(root.morphColor.r, root.morphColor.g, root.morphColor.b, 0.2)
                           : Qt.rgba(1,1,1,0.05)
                    border.color: root.currentLocale === modelData.id ? root.morphColor : "transparent"
                    border.width: root.currentLocale === modelData.id ? 2 : 0
                    Behavior on border.color { ColorAnimation { duration: 400 } }

                    Column {
                        anchors.centerIn: parent
                        spacing: 2
                        Text {
                            text: modelData.label
                            color: root.currentLocale === modelData.id ? "white" : Qt.rgba(1,1,1,0.3)
                            font.family: SiM.TransparentWorld.fontFamilyMono
                            font.pixelSize: 11; font.bold: true
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                        Text {
                            text: modelData.desc
                            color: root.currentLocale === modelData.id ? root.morphColor : Qt.rgba(1,1,1,0.2)
                            font.family: SiM.TransparentWorld.fontFamilyMono
                            font.pixelSize: 9
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                    }
                }
            }
        }

        // ── Signature ──
        Text {
            text: "SIGNATURE: " + root.localeSignature
            color: root.morphColor
            font.family: SiM.TransparentWorld.fontFamilyMono
            font.pixelSize: 8; opacity: 0.5
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: root.morphColor; opacity: 0.2 }

        // ── Content area ──
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            Text {
                anchors.centerIn: parent
                text: {
                    if (root.currentLocale === 1) return "🌐 WEAVING CLEAR NET\n[Locale I — Familiar Physical World]"
                    if (root.currentLocale === 2) return "🌑 WEAVING DARK NET\n[Locale II — Astral-Mental World]"
                    return "📦 WEAVING IPFS\n[Locale III — Alternate Physical World]"
                }
                color: root.morphColor
                font.family: SiM.TransparentWorld.fontFamilyMono
                font.pixelSize: 22; font.bold: true
                horizontalAlignment: Text.AlignHCenter; opacity: 0.8

                SequentialAnimation on opacity {
                    loops: Animation.Infinite
                    running: root.visible
                    NumberAnimation { from: 0.6; to: 1.0; duration: 2000; easing.type: Easing.InOutSine }
                    NumberAnimation { from: 1.0; to: 0.6; duration: 2000; easing.type: Easing.InOutSine }
                }
            }

            Rectangle {
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width * 0.9; height: 40; radius: 4
                color: Qt.rgba(1,1,1,0.05)
                border.color: Qt.rgba(root.morphColor.r, root.morphColor.g, root.morphColor.b, 0.2)

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12; anchors.rightMargin: 12
                    Text { text: ">"; color: root.morphColor; font.family: SiM.TransparentWorld.fontFamilyMono; font.pixelSize: 14 }
                    Text {
                        text: "Enter reality coordinates or URI to weave…"
                        color: Qt.rgba(1,1,1,0.2)
                        font.family: SiM.TransparentWorld.fontFamilyMono; font.pixelSize: 11
                        Layout.fillWidth: true
                    }
                }
            }
        }
    }
}
