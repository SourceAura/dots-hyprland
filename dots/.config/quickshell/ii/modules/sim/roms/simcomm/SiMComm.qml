/* SiMComm.qml — AI Chat ROM (dots-hyprland port)
 * ===========================
 * Direct WebSocket connection to the SiM backend (Ollama bridge).
 * Streams responses token-by-token. Stays alive mid-inference (§17.8).
 *
 * Per §16: visible gates on stable condition only; opacity handles
 * data-driven show/hide so Behavior transitions always fire.
 */
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import QtWebSockets
import "../../../../services/sim" as SiM

Item {
    id: root
    anchors.fill: parent

    property color morphColor: SiM.SiMSovereign.prismaticColor
    property var   ctrl:       null

    // ── WebSocket — stays alive while open OR streaming (§17.8) ──────
    WebSocket {
        id: _ws
        url: "ws://127.0.0.1:8765/intelligence-feed"
        active: root.visible || SiM.SiMSovereign.simStreaming

        onTextMessageReceived: function(msg) {
            try { _handle(JSON.parse(msg)) } catch(e) {}
        }

        onStatusChanged: {
            if (status === WebSocket.Open) {
                SiM.SiMSovereign.daemonState = "alive"
            } else if (status === WebSocket.Error || status === WebSocket.Closed) {
                if (SiM.SiMSovereign.simStreaming)
                    SiM.SiMSovereign.simStreaming = false
                SiM.SiMSovereign.daemonState = "dead"
            }
        }
    }

    function ask(query) {
        if (!query.trim()) return
        SiM.SiMSovereign.pushMessage("user", query)
        SiM.SiMSovereign.simStreaming = true
        SiM.SiMSovereign.simPhase    = "recall"
        SiM.SiMSovereign.simLiveText = ""
        _ws.sendTextMessage(JSON.stringify({
            type:            "SIM_QUERY",
            message:         query,
            breathing_style: SiM.SiMSovereign.breathingStyle
        }))
    }

    function _handle(d) {
        var t = d.type || ""
        if (t === "pulse") {
            SiM.SiMSovereign.sysCpu = (d.vitals && d.vitals.cpu)    ? d.vitals.cpu / 100.0    : 0
            SiM.SiMSovereign.sysRam = (d.vitals && d.vitals.memory) ? d.vitals.memory / 100.0 : 0
            return
        }
        if (t === "INFERENCE_START") { SiM.SiMSovereign.simPhase = "recall"; return }
        if (t === "THINKING_PHASE")  { SiM.SiMSovereign.simPhase = d.phase || "reason"; return }
        if (t === "STREAM_TOKEN") {
            SiM.SiMSovereign.simLiveText += d.token || ""
            SiM.SiMSovereign.simStreaming = true
            return
        }
        if (t === "STREAM_END" || t === "SIM_RESPONSE") {
            var response = d.response || SiM.SiMSovereign.simLiveText
            SiM.SiMSovereign.simLiveText  = ""
            SiM.SiMSovereign.simStreaming = false
            SiM.SiMSovereign.simPhase     = "idle"
            if (response) SiM.SiMSovereign.pushMessage("sim", response)
            return
        }
    }

    // ── Layout ────────────────────────────────────────────────────────
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        // Header
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Text {
                text: "◈  SiM"
                color: root.morphColor
                font.family: SiM.TransparentWorld.fontFamilyMono
                font.pixelSize: SiM.TransparentWorld.fontSizeLabel
                font.bold: true
                font.letterSpacing: 2
            }

            // Streaming indicator dot
            Rectangle {
                width: 7; height: 7; radius: 4
                visible: root.visible
                opacity: SiM.SiMSovereign.simStreaming ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: 180 } }
                color: root.morphColor
                SequentialAnimation on opacity {
                    loops: Animation.Infinite
                    running: SiM.SiMSovereign.simStreaming
                    NumberAnimation { to: 0.25; duration: 500 }
                    NumberAnimation { to: 1.0;  duration: 500 }
                }
            }

            Text {
                text: {
                    if (SiM.SiMSovereign.simPhase === "recall")  return "thinking…"
                    if (SiM.SiMSovereign.simPhase === "reason")  return "reasoning…"
                    if (SiM.SiMSovereign.simPhase === "respond") return "responding…"
                    return SiM.SiMSovereign.daemonState === "alive" ? "ready" : "offline"
                }
                color: SiM.TransparentWorld.textDim
                font.family: SiM.TransparentWorld.fontFamilyMono
                font.pixelSize: SiM.TransparentWorld.fontSizeMicro
                font.italic: true
            }

            Item { Layout.fillWidth: true }

            // Clear button
            Rectangle {
                width: 20; height: 20; radius: 4
                color: _clearHov.hovered ? Qt.rgba(1, 0, 0, 0.15) : "transparent"
                border.color: Qt.rgba(1, 1, 1, 0.1)
                visible: SiM.SiMSovereign.simMessages.length > 0
                Text {
                    anchors.centerIn: parent
                    text: "✕"; color: SiM.TransparentWorld.textDim; font.pixelSize: 10
                }
                TapHandler { onTapped: SiM.SiMSovereign.clearMessages() }
                HoverHandler { id: _clearHov }
            }
        }

        // Message list — §15: ListView, never Flickable
        ListView {
            id: _list
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: false
            boundsBehavior: Flickable.StopAtBounds
            spacing: 10
            model: SiM.SiMSovereign.simMessages

            delegate: Item {
                id: _msgItem
                required property var modelData
                required property int index

                width: _list.width
                implicitHeight: _bubble.implicitHeight
                height: implicitHeight

                readonly property bool  _isUser: modelData.role === "user"
                readonly property color _rc: _isUser ? Qt.rgba(1,1,1,0.55) : root.morphColor

                Rectangle {
                    id: _bubble
                    anchors.left:  _msgItem._isUser ? undefined : parent.left
                    anchors.right: _msgItem._isUser ? parent.right : undefined
                    width: Math.min(_txt.implicitWidth + 24, parent.width * 0.88)
                    implicitHeight: _txt.implicitHeight + 16
                    radius: 8
                    color: _msgItem._isUser
                        ? Qt.rgba(1,1,1,0.05)
                        : Qt.rgba(root.morphColor.r, root.morphColor.g, root.morphColor.b, 0.08)
                    border.color: Qt.rgba(_msgItem._rc.r, _msgItem._rc.g, _msgItem._rc.b, 0.20)
                    border.width: 1

                    Text {
                        id: _txt
                        anchors { left: parent.left; right: parent.right; margins: 12 }
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.text || ""
                        color: _msgItem._isUser
                            ? Qt.rgba(1,1,1,0.82)
                            : Qt.rgba(root.morphColor.r, root.morphColor.g, root.morphColor.b, 0.95)
                        font.family:    SiM.TransparentWorld.fontFamilyMono
                        font.pixelSize: SiM.TransparentWorld.fontSizeBase
                        wrapMode:       Text.WordWrap
                        lineHeight:     1.4
                    }
                }
            }

            footer: Item {
                width: _list.width
                visible: root.visible
                height: SiM.SiMSovereign.simStreaming ? _streamBubble.implicitHeight + 10 : 0
                implicitHeight: height
                Behavior on height { NumberAnimation { duration: 180 } }

                Rectangle {
                    id: _streamBubble
                    anchors.left: parent.left
                    width: Math.min(_streamTxt.implicitWidth + 24, parent.width * 0.88)
                    implicitHeight: _streamTxt.implicitHeight + 16
                    radius: 8
                    color: Qt.rgba(root.morphColor.r, root.morphColor.g, root.morphColor.b, 0.08)
                    border.color: Qt.rgba(root.morphColor.r, root.morphColor.g, root.morphColor.b, 0.30)
                    border.width: 1
                    visible: root.visible
                    opacity: SiM.SiMSovereign.simStreaming ? 1.0 : 0.0
                    Behavior on opacity { NumberAnimation { duration: 180 } }

                    Row {
                        anchors.centerIn: parent
                        spacing: 5
                        visible: SiM.SiMSovereign.simPhase === "recall"
                              && SiM.SiMSovereign.simLiveText === ""
                        Repeater {
                            model: 3
                            delegate: Rectangle {
                                required property int index
                                width: 5; height: 5; radius: 3
                                color: root.morphColor
                                opacity: 0.4
                                SequentialAnimation on opacity {
                                    loops: Animation.Infinite
                                    running: SiM.SiMSovereign.simPhase === "recall"
                                    PauseAnimation  { duration: index * 160 }
                                    NumberAnimation { to: 1.0; duration: 380 }
                                    NumberAnimation { to: 0.4; duration: 380 }
                                }
                            }
                        }
                    }

                    Text {
                        id: _streamTxt
                        anchors { left: parent.left; right: parent.right; margins: 12 }
                        anchors.verticalCenter: parent.verticalCenter
                        text: SiM.SiMSovereign.simLiveText
                        visible: SiM.SiMSovereign.simLiveText !== ""
                        color: Qt.rgba(root.morphColor.r, root.morphColor.g, root.morphColor.b, 0.90)
                        font.family:    SiM.TransparentWorld.fontFamilyMono
                        font.pixelSize: SiM.TransparentWorld.fontSizeBase
                        wrapMode:       Text.WordWrap
                        lineHeight:     1.4
                    }
                }
            }

            onCountChanged: Qt.callLater(function() { positionViewAtEnd() })
        }
    }
}
