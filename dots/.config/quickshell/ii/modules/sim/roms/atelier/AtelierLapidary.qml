/* AtelierLapidary.qml — IPFS Vault tab */
import QtQuick
import QtQuick.Layouts
import "../../../../services/sim" as SiM

ColumnLayout {
    spacing: 12

    property color accent: "#f59e0b"

    RowLayout {
        Layout.fillWidth: true
        Text {
            text: "⊛ LAPIDARY: UNIFIED SYSTEM VAULT"
            color: accent
            font.family: SiM.TransparentWorld.fontFamilyMono
            font.pixelSize: 12; font.bold: true
        }
        Item { Layout.fillWidth: true }
        Text {
            text: "STATUS: SYNCING"
            color: accent
            font.family: SiM.TransparentWorld.fontFamilyMono
            font.pixelSize: 10
            SequentialAnimation on opacity {
                loops: Animation.Infinite
                running: parent.visible
                NumberAnimation { to: 0.3; duration: 600 }
                NumberAnimation { to: 1.0; duration: 600 }
            }
        }
    }

    GridLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        columns: 2; rowSpacing: 10; columnSpacing: 10

        Rectangle {
            Layout.fillWidth: true; Layout.fillHeight: true
            radius: 12; color: Qt.rgba(0,0,0,0.4)
            border.color: Qt.rgba(Qt.color(accent).r, Qt.color(accent).g, Qt.color(accent).b, 0.2)
            ColumnLayout {
                anchors.centerIn: parent; spacing: 8
                Text { text: "⬡"; color: accent; font.pixelSize: 24; Layout.alignment: Qt.AlignHCenter }
                Text { text: "IPFS GATEWAY"; color: "white"; font.family: SiM.TransparentWorld.fontFamilyMono; font.pixelSize: 10; font.bold: true; Layout.alignment: Qt.AlignHCenter }
                Text { text: "127.0.0.1:8080"; color: Qt.rgba(1,1,1,0.3); font.family: SiM.TransparentWorld.fontFamilyMono; font.pixelSize: 9; Layout.alignment: Qt.AlignHCenter }
            }
        }

        Rectangle {
            Layout.fillWidth: true; Layout.fillHeight: true
            radius: 12; color: Qt.rgba(0,0,0,0.4)
            border.color: Qt.rgba(Qt.color(accent).r, Qt.color(accent).g, Qt.color(accent).b, 0.2)
            ColumnLayout {
                anchors.centerIn: parent; spacing: 8
                Text { text: "1.2 GB"; color: "white"; font.family: SiM.TransparentWorld.fontFamilyMono; font.pixelSize: 18; font.bold: true; Layout.alignment: Qt.AlignHCenter }
                Text { text: "TOTAL VAULT SIZE"; color: Qt.rgba(1,1,1,0.3); font.family: SiM.TransparentWorld.fontFamilyMono; font.pixelSize: 9; Layout.alignment: Qt.AlignHCenter }
            }
        }
    }
}
