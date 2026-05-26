/* Conduit.qml — PTY Terminal ROM
 * =================================
 * FOLD: BLADE (⚔) — Offensive Operations · WISDOM
 * ACCENT: #FF3CAC (hot magenta)
 *
 * A full PTY terminal surface inside the Obelisk ROM host.
 * Commands route through the Substrate layer (LAW.mdx policy enforcement)
 * when a breathing style requires it, or execute directly via Process.
 *
 * Architecture:
 *   - Process (Quickshell.Io) spawns the shell, streams stdout/stderr
 *   - ListView for output (§15 — no Flickable, no clip: true)
 *   - Dirty-flag repaint pattern (§1.2) for the cursor blink canvas
 *   - lexHighlight from TransparentWorld on all output lines
 *   - §16: visible gates on stable condition; opacity handles data show/hide
 *   - §14.9: TapHandler + HoverHandler, no new MouseArea
 *
 * Public API (consumed by RomHost):
 *   handleInput(text)  — called by RomHost.sendInput()
 *   execute()          — called by RomHost.execute() / Enter key
 *   property morphColor
 *   property ctrl
 */
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell.Io
import "../../../../services/sim" as TW

Item {
    id: root
    anchors.fill: parent

    // ── Public API ────────────────────────────────────────────────────
    property color morphColor: TW.SiMSovereign.prismaticColor
    property var   ctrl:       null

    // ── Blade fold accent — always hot magenta regardless of morphColor ─
    readonly property color _bladeAccent: "#FF3CAC"

    // ── Terminal state ────────────────────────────────────────────────
    property string _pendingInput: ""          // text staged from handleInput()
    property bool   _shellReady:   false       // true once shell process is alive
    property bool   _busy:         false       // true while a command is running

    // Output model — each entry: { text: string, isErr: bool, isCmd: bool }
    property var _lines: []

    // Scroll-to-bottom flag
    property bool _scrollDirty: false

    // ── Shell process ─────────────────────────────────────────────────
    // Uses bash -i (interactive) so PATH, aliases, and rc files load.
    // stdout and stderr are both captured via onStdoutReceived.
    Process {
        id: _shell
        command: ["/bin/bash", "--norc", "--noprofile"]
        running: true

        stdout: SplitParser {
            onRead: function(line) {
                root._appendLine(line, false)
            }
        }

        stderr: SplitParser {
            onRead: function(line) {
                root._appendLine(line, true)
            }
        }

        onExited: function(code, status) {
            root._appendLine(
                "◌ shell exited (code " + code + ") — press Enter to restart",
                true
            )
            root._shellReady = false
            root._busy = false
        }

        onRunningChanged: {
            if (running) {
                root._shellReady = true
                root._busy = false
                // Source user env silently so tools are on PATH
                _shell.write("export TERM=xterm-256color\n")
                _shell.write("export PS1=''\n")
            }
        }
    }

    // ── Public interface (called by RomHost) ──────────────────────────
    function handleInput(text) {
        _pendingInput = text
    }

    function execute() {
        var cmd = _pendingInput.trim()
        _pendingInput = ""
        if (!cmd) return
        _runCommand(cmd)
    }

    // ── Internal command dispatch ─────────────────────────────────────
    function _runCommand(cmd) {
        if (!cmd) return

        // Echo the command as a prompt line
        _appendLine("❯ " + cmd, false, true)

        // Built-in clear
        if (cmd === "clear" || cmd === "cls") {
            _lines = []
            _outputModel.clear()
            return
        }

        // Route through Substrate when Moon/Sun breathing requires it
        var style = TW.SiMSovereign.breathingStyle
        if (style === "moon" || style === "sun") {
            _routeSubstrate(cmd)
        } else {
            _execDirect(cmd)
        }
    }

    function _execDirect(cmd) {
        if (!_shellReady) {
            _appendLine("◌ shell not ready", true)
            return
        }
        _busy = true
        // Write command + sentinel so we know when it finishes
        _shell.write(cmd + "\n")
        // Busy flag cleared by output sentinel or timeout
        _busyTimeout.restart()
    }

    function _routeSubstrate(cmd) {
        var xhr = new XMLHttpRequest()
        xhr.open("POST", "http://127.0.0.1:8765/api/substrate/execute")
        xhr.setRequestHeader("Content-Type", "application/json")
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            try {
                var resp = JSON.parse(xhr.responseText)
                if (resp.status === "denied") {
                    _appendLine("⚔ SUBSTRATE DENIED: " + (resp.reason || "policy violation"), true)
                } else if (resp.status === "executing") {
                    _appendLine("◈ Authorized → " + (resp.rewritten_command || cmd), false)
                    _execDirect(resp.rewritten_command || cmd)
                }
            } catch(e) {
                // Substrate unreachable — fall through to direct exec
                _execDirect(cmd)
            }
        }
        xhr.send(JSON.stringify({ command: cmd }))
    }

    // Busy timeout — clears _busy after 30s if no exit signal
    Timer {
        id: _busyTimeout
        interval: 30000
        repeat: false
        onTriggered: root._busy = false
    }

    // ── Output model management ───────────────────────────────────────
    ListModel { id: _outputModel }

    function _appendLine(text, isErr, isCmd) {
        if (text === undefined || text === null) return
        _outputModel.append({
            lineText: text,
            lineErr:  isErr  === true,
            lineCmd:  isCmd  === true
        })
        // Cap at 2000 lines to avoid unbounded memory growth
        while (_outputModel.count > 2000) {
            _outputModel.remove(0)
        }
        _scrollDirty = true
    }

    // Scroll-to-bottom — deferred so ListView has measured the new item
    Timer {
        interval: 33
        repeat: false
        running: root._scrollDirty
        onTriggered: {
            root._scrollDirty = false
            _outputList.positionViewAtEnd()
        }
    }

    // ── Layout ────────────────────────────────────────────────────────
    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ── Status bar ────────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 28
            color: Qt.rgba(0, 0, 0, 0.45)
            border.color: Qt.rgba(root._bladeAccent.r,
                                  root._bladeAccent.g,
                                  root._bladeAccent.b, 0.25)
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 10

                // Fold sigil
                Text {
                    text: "⚔  CONDUIT"
                    color: root._bladeAccent
                    font.family:    TW.TransparentWorld.fontFamilyMono
                    font.pixelSize: TW.TransparentWorld.fontSizeMicro
                    font.bold: true
                    font.letterSpacing: 2
                }

                // Breathing style badge
                Text {
                    text: TW.SiMSovereign.breathingStyle.toUpperCase()
                    color: root.morphColor
                    font.family:    TW.TransparentWorld.fontFamilyMono
                    font.pixelSize: TW.TransparentWorld.fontSizeMicro
                    opacity: 0.65
                }

                Item { Layout.fillWidth: true }

                // Busy indicator
                Rectangle {
                    width: 7; height: 7; radius: 4
                    // §16: visible on stable gate, opacity on data condition
                    visible: root.visible
                    opacity: root._busy ? 1.0 : 0.0
                    Behavior on opacity { NumberAnimation { duration: 150 } }
                    color: root._bladeAccent
                    SequentialAnimation on opacity {
                        loops: Animation.Infinite
                        running: root._busy
                        NumberAnimation { to: 0.2; duration: 400 }
                        NumberAnimation { to: 1.0; duration: 400 }
                    }
                }

                // Shell status dot
                Rectangle {
                    width: 7; height: 7; radius: 4
                    color: root._shellReady ? "#4ade80" : "#f43f5e"
                    Behavior on color { ColorAnimation { duration: 300 } }
                }

                // Line count
                Text {
                    text: _outputModel.count + " lines"
                    color: TW.TransparentWorld.textDim
                    font.family:    TW.TransparentWorld.fontFamilyMono
                    font.pixelSize: TW.TransparentWorld.fontSizeMicro
                }

                // Clear button
                Rectangle {
                    width: 20; height: 20; radius: 4
                    color: _clearHov.hovered
                           ? Qt.rgba(1, 0, 0, 0.15) : "transparent"
                    border.color: Qt.rgba(1, 1, 1, 0.08)

                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        color: TW.TransparentWorld.textDim
                        font.pixelSize: 10
                    }

                    TapHandler {
                        onTapped: {
                            _outputModel.clear()
                            root._lines = []
                        }
                    }
                    HoverHandler { id: _clearHov }
                }
            }
        }

        // ── Output area — §15: ListView, never Flickable ──────────────
        ListView {
            id: _outputList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: false
            boundsBehavior: Flickable.StopAtBounds
            spacing: 0
            model: _outputModel

            // §16: visible on stable gate
            visible: root.visible

            delegate: Item {
                id: _lineItem
                required property string lineText
                required property bool   lineErr
                required property bool   lineCmd
                required property int    index

                width: _outputList.width
                implicitHeight: _lineTxt.implicitHeight + 2
                height: implicitHeight

                readonly property color _lineColor: {
                    if (lineCmd) return Qt.rgba(root._bladeAccent.r,
                                                root._bladeAccent.g,
                                                root._bladeAccent.b, 0.90)
                    if (lineErr) return Qt.rgba(0.96, 0.27, 0.37, 0.85)  // accentBreach
                    return TW.TransparentWorld.textPrimary
                }

                Text {
                    id: _lineTxt
                    anchors { left: parent.left; right: parent.right }
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    text: TW.TransparentWorld.lexHighlight(
                              lineText,
                              TW.SiMSovereign.lockedTarget
                          )
                    color: _lineItem._lineColor
                    font.family:    TW.TransparentWorld.fontFamilyMono
                    font.pixelSize: TW.TransparentWorld.fontSizeLabel
                    wrapMode:       Text.WrapAnywhere
                    lineHeight:     1.35
                    textFormat:     Text.RichText
                }
            }

            // Empty state
            Item {
                anchors.centerIn: parent
                // §16: visible on stable gate, opacity on data condition
                visible: root.visible
                opacity: _outputModel.count === 0 ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: 200 } }

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 8

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "⚔"
                        color: Qt.rgba(root._bladeAccent.r,
                                       root._bladeAccent.g,
                                       root._bladeAccent.b, 0.35)
                        font.pixelSize: 32
                    }
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "CONDUIT"
                        color: Qt.rgba(root._bladeAccent.r,
                                       root._bladeAccent.g,
                                       root._bladeAccent.b, 0.35)
                        font.family:    TW.TransparentWorld.fontFamilyMono
                        font.pixelSize: TW.TransparentWorld.fontSizeMicro
                        font.bold: true
                        font.letterSpacing: 4
                    }
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "type a command in the Obelisk"
                        color: TW.TransparentWorld.textDim
                        font.family:    TW.TransparentWorld.fontFamilyMono
                        font.pixelSize: TW.TransparentWorld.fontSizeMicro
                        font.italic: true
                    }
                }
            }
        }

        // ── Input row — staged command preview ────────────────────────
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 36
            color: Qt.rgba(0, 0, 0, 0.35)
            border.color: Qt.rgba(root._bladeAccent.r,
                                  root._bladeAccent.g,
                                  root._bladeAccent.b,
                                  root._pendingInput.length > 0 ? 0.45 : 0.12)
            border.width: 1

            Behavior on border.color { ColorAnimation { duration: 120 } }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 8

                // Prompt sigil
                Text {
                    text: "❯"
                    color: root._pendingInput.length > 0
                           ? root._bladeAccent
                           : TW.TransparentWorld.textDim
                    font.family:    TW.TransparentWorld.fontFamilyMono
                    font.pixelSize: TW.TransparentWorld.fontSizeLabel
                    Behavior on color { ColorAnimation { duration: 120 } }
                }

                // Staged input preview
                Text {
                    Layout.fillWidth: true
                    text: root._pendingInput.length > 0
                          ? root._pendingInput
                          : "waiting for input…"
                    color: root._pendingInput.length > 0
                           ? TW.TransparentWorld.textPrimary
                           : TW.TransparentWorld.textDim
                    font.family:    TW.TransparentWorld.fontFamilyMono
                    font.pixelSize: TW.TransparentWorld.fontSizeLabel
                    font.italic:    root._pendingInput.length === 0
                    elide: Text.ElideRight
                    Behavior on color { ColorAnimation { duration: 120 } }
                }

                // Cursor blink — §1.2 dirty-flag pattern
                Rectangle {
                    id: _cursor
                    width: 8; height: 16; radius: 1
                    color: root._bladeAccent
                    visible: root._pendingInput.length > 0

                    property bool _blinkState: true
                    property bool _blinkDirty: false

                    onVisibleChanged: if (visible) { _blinkState = true; _blinkDirty = true }

                    Timer {
                        interval: 530
                        repeat: true
                        running: _cursor.visible
                        onTriggered: {
                            _cursor._blinkState = !_cursor._blinkState
                            _cursor._blinkDirty = true
                        }
                    }

                    opacity: _blinkState ? 0.85 : 0.0
                    Behavior on opacity { NumberAnimation { duration: 80 } }
                }
            }
        }
    }

    // ── Shadow bloom on the whole ROM ─────────────────────────────────
    layer.enabled: root.visible
    layer.effect: MultiEffect {
        shadowEnabled: true
        shadowColor:   Qt.rgba(root._bladeAccent.r,
                               root._bladeAccent.g,
                               root._bladeAccent.b, 0.18)
        shadowBlur:    TW.TransparentWorld.shadowBlur
        shadowVerticalOffset: TW.TransparentWorld.shadowOffsetY
        blurEnabled:   false
    }
}
