/* AtelierSiMStrip.qml — Bottom analytics strip */
import QtQuick
import QtQuick.Layouts
import "../../../../services/sim" as SiM

Rectangle {
    id: root
    width: parent ? parent.width : 0
    height: 36; radius: 8
    color: Qt.rgba(0,0,0,0.4)
    border.color: Qt.rgba(1,1,1,0.05)

    property color accent: SiM.SiMSovereign.prismaticColor

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12; anchors.rightMargin: 12
        spacing: 12

        Rectangle {
            width: 8; height: 8; radius: 4
            color: root.accent
            SequentialAnimation on opacity {
                loops: Animation.Infinite
                running: root.visible
                NumberAnimation { to: 0.2; duration: 800 }
                NumberAnimation { to: 1.0; duration: 800 }
            }
        }

        Text {
            text: "SiM ANALYTICS ACTIVE"
            color: root.accent
            font.family: SiM.TransparentWorld.fontFamilyMono
            font.pixelSize: 10; font.bold: true; font.letterSpacing: 1
        }

        Item { Layout.fillWidth: true }

        Row {
            spacing: 16
            Repeater {
                model: [
                    { label: "THROUGHPUT", value: "128 t/s" },
                    { label: "LATENCY",    value: "42ms"    },
                    { label: "COHERENCE",  value: "0.98"    }
                ]
                delegate: Row {
                    required property var modelData
                    spacing: 6
                    Text { text: modelData.label; color: Qt.rgba(1,1,1,0.3); font.family: SiM.TransparentWorld.fontFamilyMono; font.pixelSize: 9 }
                    Text { text: modelData.value; color: "white"; font.family: SiM.TransparentWorld.fontFamilyMono; font.pixelSize: 10; font.bold: true }
                }
            }
        }
    }
}
