/* AtelierAbyss.qml — Docker container management tab */
import QtQuick
import QtQuick.Layouts
import "../../../../services/sim" as SiM

ColumnLayout {
    spacing: 12

    property color accent: "#4ade80"

    RowLayout {
        Layout.fillWidth: true
        Text {
            text: "🐳 ABYSSAL RANGE: VIRTUAL ENVIRONMENTS"
            color: accent
            font.family: SiM.TransparentWorld.fontFamilyMono
            font.pixelSize: 12; font.bold: true
        }
        Item { Layout.fillWidth: true }
        Text {
            text: "RUNTIME: DOCKER"
            color: Qt.rgba(1,1,1,0.3)
            font.family: SiM.TransparentWorld.fontFamilyMono
            font.pixelSize: 10
        }
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.fillHeight: true
        radius: 12
        color: Qt.rgba(0,0,0,0.4)
        border.color: Qt.rgba(Qt.color(accent).r, Qt.color(accent).g, Qt.color(accent).b, 0.2)

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 12

            Text {
                text: "∿"
                color: accent; font.pixelSize: 32
                Layout.alignment: Qt.AlignHCenter
                SequentialAnimation on opacity {
                    loops: Animation.Infinite
                    running: parent.visible
                    NumberAnimation { to: 0.2; duration: 1200 }
                    NumberAnimation { to: 1.0; duration: 1200 }
                }
            }
            Text {
                text: "NO ACTIVE CONTAINERS"
                color: Qt.rgba(1,1,1,0.3)
                font.family: SiM.TransparentWorld.fontFamilyMono
                font.pixelSize: 10
                Layout.alignment: Qt.AlignHCenter
            }
            Rectangle {
                width: 120; height: 24; radius: 6
                color: Qt.rgba(Qt.color(accent).r, Qt.color(accent).g, Qt.color(accent).b, 0.1)
                border.color: accent
                Layout.alignment: Qt.AlignHCenter
                Text {
                    anchors.centerIn: parent
                    text: "LAUNCH RANGE"
                    color: "white"
                    font.family: SiM.TransparentWorld.fontFamilyMono
                    font.pixelSize: 9; font.bold: true
                }
                TapHandler { onTapped: SiM.SiMSovereign.runNativeCommand("docker ps") }
            }
        }
    }
}
