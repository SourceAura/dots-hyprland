/* SiMTab.qml — SiM sidebar tab content for end4's sidebar
 * ==================================================================
 * DESTINATION: .config/quickshell/modules/sim/SiMTab.qml
 *
 * This is the complete SiM tab that slots into end4's existing
 * sidebar tab system. It does NOT modify any of end4's existing tabs.
 *
 * Wiring in end4's SidebarLeftContent.qml:
 *
 *   import "./sim" as SiMTab
 *
 *   // Add to their existing tab model:
 *   { id: "sim", label: "SiM", icon: "◈" }
 *
 *   // Add to their StackLayout:
 *   SiMTab.SiMTab {
 *       Layout.fillWidth: true
 *       Layout.fillHeight: true
 *       visible: currentTab === "sim"
 *   }
 *
 * Layout (top → bottom):
 *   ┌─────────────────────────────────────────────────────┐
 *   │ [◈ PRISMATIC ▾]  [☽ MOON]  [☀ SUN]                │  ← SiMBreathingMode
 *   │ ─────────────────────────────────────────────────── │
 *   │ [⚔ nmap] [⚔ nuclei] [◉ subfinder] [◉ httpx] ...   │  ← SiMRunePanel
 *   │ ─────────────────────────────────────────────────── │
 *   │ ∿  speak or command                                 │  ← SiMCommandBar
 *   │ ─────────────────────────────────────────────────── │
 *   │ [message area / response stream]                    │  ← SiMComm inline
 *   └─────────────────────────────────────────────────────┘
 *
 * §15: ListView for message list, never Flickable
 * §16: visible on stable gate; opacity on data condition
 * §14.9: TapHandler + HoverHandler only
 */
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import QtWebSockets
import "../../services/sim" as SiM


Item {
    id: root

    // ── Sovereign confirmation message ────────────────────────────────
    property string _sovereignMsg: ""

    // ── Layout ────────────────────────────────────────────────────────
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 10

        // ── Breathing mode switcher ───────────────────────────────────
        SiMBreathingMode {
            Layout.fillWidth: true
        }

        // ── Divider ───────────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Qt.rgba(SiM.SiMSovereign.prismaticColor.r,
                           SiM.SiMSovereign.prismaticColor.g,
                           SiM.SiMSovereign.prismaticColor.b, 0.15)
            Behavior on color { ColorAnimation { duration: 300 } }
        }

        // ── Rune panel ────────────────────────────────────────────────
        SiMRunePanel {
            Layout.fillWidth: true
            onRuneSelected: function(rune) {
                _cmdBar.lockedTokens = [rune]
                _cmdBar.focusInput()
            }
        }

        // ── Command bar ───────────────────────────────────────────────
        SiMCommandBar {
            id: _cmdBar
            Layout.fillWidth: true
            morphColor: SiM.SiMSovereign.prismaticColor

            onCommandExecuted: function(cmd, intent) {
                if (intent.isRom) {
                    SiM.SiMSovereign.toggleRom(intent.romId)
                } else if (intent.isConv || intent.cmd === "") {
                    // Route to SiMComm inline chat
                    _simComm.ask(cmd)
                } else if (intent.cmd !== "") {
                    // Shell command → open Conduit ROM and run it
                    SiM.SiMSovereign.toggleRom("conduit")
                    // Conduit will receive the command via the ROM's handleInput/execute API
                    // This is wired through SiMSovereign.activeRom → shell.qml Loader
                }
            }

            onCloseRequested: {
                // In sidebar context, just clear the input
                lockedTokens = []
            }
        }

        // ── Sovereign confirmation message ────────────────────────────
        // §16: visible on stable gate, opacity on data condition
        Item {
            Layout.fillWidth: true
            visible: root.visible
            height: root._sovereignMsg !== "" ? _sovereignTxt.implicitHeight + 12 : 0
            implicitHeight: height
            Behavior on height { NumberAnimation { duration: 180 } }

            Rectangle {
                anchors.fill: parent
                radius: 6
                color: Qt.rgba(SiM.SiMSovereign.prismaticColor.r,
                               SiM.SiMSovereign.prismaticColor.g,
                               SiM.SiMSovereign.prismaticColor.b, 0.08)
                border.color: Qt.rgba(SiM.SiMSovereign.prismaticColor.r,
                                      SiM.SiMSovereign.prismaticColor.g,
                                      SiM.SiMSovereign.prismaticColor.b, 0.25)
                border.width: 1
                visible: root._sovereignMsg !== ""

                Text {
                    id: _sovereignTxt
                    anchors { left: parent.left; right: parent.right; margins: 10 }
                    anchors.verticalCenter: parent.verticalCenter
                    text: root._sovereignMsg
                    color: SiM.SiMSovereign.prismaticColor
                    font.family:    "3270 Nerd Font Mono, Fira Code, monospace"
                    font.pixelSize: 11
                    font.italic:    true
                    wrapMode:       Text.WordWrap
                }
            }
        }

        // ── Divider ───────────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Qt.rgba(1, 1, 1, 0.06)
            // §16: visible on stable gate, opacity on data condition
            visible: root.visible
            opacity: SiM.SiMSovereign.simMessages.length > 0
                  || SiM.SiMSovereign.simStreaming ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: 200 } }
        }

        // ── Inline SiMComm — message list ─────────────────────────────
        // §15: ListView, never Flickable
        ListView {
            id: _msgList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: false
            boundsBehavior: Flickable.StopAtBounds
            spacing: 8
            model: SiM.SiMSovereign.simMessages

            // §16: visible on stable gate
            visible: root.visible

            delegate: Item {
                id: _msgItem
                required property var  modelData
                required property int  index

                width: _msgList.width
                implicitHeight: _bubble.implicitHeight
                height: implicitHeight

                readonly property bool  _isUser: modelData.role === "user"
                readonly property color _rc: _isUser
                    ? Qt.rgba(1, 1, 1, 0.55)
                    : SiM.SiMSovereign.prismaticColor

                Rectangle {
                    id: _bubble
                    anchors.left:  _msgItem._isUser ? undefined : parent.left
                    anchors.right: _msgItem._isUser ? parent.right : undefined
                    width: Math.min(_txt.implicitWidth + 20, parent.width * 0.90)
                    implicitHeight: _txt.implicitHeight + 14
                    radius: 8
                    color: _msgItem._isUser
                        ? Qt.rgba(1, 1, 1, 0.05)
                        : Qt.rgba(SiM.SiMSovereign.prismaticColor.r,
                                  SiM.SiMSovereign.prismaticColor.g,
                                  SiM.SiMSovereign.prismaticColor.b, 0.08)
                    border.color: Qt.rgba(_msgItem._rc.r, _msgItem._rc.g,
                                          _msgItem._rc.b, 0.20)
                    border.width: 1

                    Text {
                        id: _txt
                        anchors { left: parent.left; right: parent.right; margins: 10 }
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.text || ""
                        color: _msgItem._isUser
                            ? Qt.rgba(1, 1, 1, 0.82)
                            : Qt.rgba(SiM.SiMSovereign.prismaticColor.r,
                                      SiM.SiMSovereign.prismaticColor.g,
                                      SiM.SiMSovereign.prismaticColor.b, 0.95)
                        font.family:    "3270 Nerd Font Mono, Fira Code, monospace"
                        font.pixelSize: 12
                        wrapMode:       Text.WordWrap
                        lineHeight:     1.4
                    }
                }
            }

            // Live streaming footer
            footer: Item {
                width: _msgList.width
                // §16: visible on stable gate
                visible: root.visible
                height: SiM.SiMSovereign.simStreaming
                        ? _streamBubble.implicitHeight + 8 : 0
                implicitHeight: height
                Behavior on height { NumberAnimation { duration: 180 } }

                Rectangle {
                    id: _streamBubble
                    anchors.left: parent.left
                    width: Math.min(_streamTxt.implicitWidth + 20, parent.width * 0.90)
                    implicitHeight: _streamTxt.implicitHeight + 14
                    radius: 8
                    color: Qt.rgba(SiM.SiMSovereign.prismaticColor.r,
                                   SiM.SiMSovereign.prismaticColor.g,
                                   SiM.SiMSovereign.prismaticColor.b, 0.08)
                    border.color: Qt.rgba(SiM.SiMSovereign.prismaticColor.r,
                                          SiM.SiMSovereign.prismaticColor.g,
                                          SiM.SiMSovereign.prismaticColor.b, 0.30)
                    border.width: 1
                    // §16: visible on stable gate, opacity on data
                    visible: root.visible
                    opacity: SiM.SiMSovereign.simStreaming ? 1.0 : 0.0
                    Behavior on opacity { NumberAnimation { duration: 180 } }

                    // Thinking dots
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
                                color: SiM.SiMSovereign.prismaticColor
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
                        anchors { left: parent.left; right: parent.right; margins: 10 }
                        anchors.verticalCenter: parent.verticalCenter
                        text: SiM.SiMSovereign.simLiveText
                        visible: SiM.SiMSovereign.simLiveText !== ""
                        color: Qt.rgba(SiM.SiMSovereign.prismaticColor.r,
                                       SiM.SiMSovereign.prismaticColor.g,
                                       SiM.SiMSovereign.prismaticColor.b, 0.90)
                        font.family:    "3270 Nerd Font Mono, Fira Code, monospace"
                        font.pixelSize: 12
                        wrapMode:       Text.WordWrap
                        lineHeight:     1.4
                    }
                }
            }

            onCountChanged: Qt.callLater(function() { positionViewAtEnd() })
        }
    }

    // ── SiMComm WebSocket — lives here, not in the ROM ────────────────
    // The tab owns the WS connection so it persists across ROM switches.
    // §17.8: stays alive while tab is visible OR streaming
    QtObject {
        id: _simComm

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
    }

    // §17.8: active while tab visible OR streaming
    WebSocket {
        id: _ws
        url: "ws://127.0.0.1:8765/intelligence-feed"
        active: root.visible || SiM.SiMSovereign.simStreaming

        onTextMessageReceived: function(msg) {
            try {
                var d = JSON.parse(msg)
                var t = d.type || ""

                if (t === "pulse") {
                    SiM.SiMSovereign.sysCpu = (d.vitals && d.vitals.cpu)    ? d.vitals.cpu / 100.0    : 0
                    SiM.SiMSovereign.sysRam = (d.vitals && d.vitals.memory) ? d.vitals.memory / 100.0 : 0
                    return
                }
                if (t === "GOVERNOR_STATE") {
                    SiM.SiMSovereign.sysTemp = d.temp || 0
                    SiM.SiMSovereign.governorFrequency = d.freq || "—"
                    return
                }
                if (t === "INFERENCE_START") {
                    SiM.SiMSovereign.simPhase = "recall"; return
                }
                if (t === "THINKING_PHASE") {
                    SiM.SiMSovereign.simPhase = d.phase || "reason"; return
                }
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
            } catch(e) {}
        }

        onStatusChanged: {
            if (status === WebSocket.Open) {
                SiM.SiMSovereign.daemonState = "alive"
            } else if (status === WebSocket.Error || status === WebSocket.Closed) {
                SiM.SiMSovereign.daemonState = "dead"
                if (SiM.SiMSovereign.simStreaming)
                    SiM.SiMSovereign.simStreaming = false
            }
        }
    }
}
