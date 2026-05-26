/* SiMSovereign.qml — Breathing State Machine & System Orchestrator
 * ==================================================================
 * DESTINATION: .config/quickshell/services/sim/SiMSovereign.qml
 *
 * Ported from: soul/tw/SiMOrchestrator.qml (DMS plugin)
 *
 * This is the singleton source of truth for all SiM state in the
 * dots-hyprland integration. It replaces SiMOrchestrator.qml and
 * SovereignController.qml, merging them into one clean service.
 *
 * In dots-hyprland, access via:
 *   import "./services/sim" as SiM
 *   SiM.SiMSovereign.breathingStyle
 *
 * Breathing styles (canonical names — locked):
 *   "celestial"  — Prismatic / daily driver / default
 *   "moon"       — Stealth / passive recon
 *   "sun"        — Aggressive / offensive (requires shikai → bankai)
 *
 * Active ROM tracking:
 *   activeRom    — id of the currently open ROM ("" = none)
 *   romPath      — resolved QML path for the Loader in shell.qml
 */
pragma Singleton
import QtQuick
import Quickshell.Io

QtObject {
    id: sovereign

    // ── Breathing Style ───────────────────────────────────────────────
    // Canonical values: "celestial" | "moon" | "sun"
    property string breathingStyle: "celestial"

    // Anticipated style during typing (confidence ≥ 0.85)
    property string anticipatedStyle: ""

    // ── Locked Rune Chips / Segment Tokens ────────────────────────────
    property var lockedChips: []

    // ── Active ROM ────────────────────────────────────────────────────
    property string activeRom:  ""   // ROM id: "conduit" | "simcomm" | "atelier" | "grimoire" | "ori"
    property string romPath:    ""   // resolved QML path for Loader

    // ROM path map — canonical filenames
    readonly property var _romFiles: ({
        "conduit":  "conduit/Conduit.qml",
        "simcomm":  "simcomm/SiMComm.qml",
        "atelier":  "atelier/Atelier.qml",
        "grimoire": "grimoire/Grimoire.qml",
        "ori":      "ori/Ori.qml"
    })

    function toggleRom(id) {
        if (activeRom === id) {
            activeRom = ""
            romPath   = ""
        } else {
            activeRom = id
            romPath   = Qt.resolvedUrl("../../modules/sim/roms/" + (_romFiles[id] || id + "/" + id + ".qml")).toString()
        }
    }

    function closeRom() {
        activeRom = ""
        romPath   = ""
    }

    // ── SiM Tab visibility ────────────────────────────────────────────
    property bool simTabOpen: false

    function toggleSiMTab() {
        simTabOpen = !simTabOpen
    }

    // ── Sovereign auth state (shikai / bankai flow) ───────────────────
    property string authState: "idle"   // "idle" | "shikai_prompt" | "shikai_aligned"

    function processCommand(cmd) {
        var clean = (cmd || "").trim().toLowerCase()

        if (clean === "sun" || clean === "/style sun" || clean === "style sun") {
            authState = "shikai_prompt"
            return { handled: true, message: "RELEASE INVOCATION REQUIRED. Type 'shikai' to align core." }
        }
        if (clean === "moon" || clean === "/style moon" || clean === "style moon") {
            breathingStyle = "moon"
            authState = "idle"
            _notifyBackend("moon")
            return { handled: true, message: "☽ Moon Breathing active. Silent scanning engaged." }
        }
        if (clean === "celestial" || clean === "prismatic" || clean === "/style celestial" || clean === "style celestial") {
            breathingStyle = "celestial"
            authState = "idle"
            _notifyBackend("celestial")
            return { handled: true, message: "◈ Prismatic Balanced Mode active." }
        }
        if (clean === "shikai") {
            if (authState === "shikai_prompt") {
                authState = "shikai_aligned"
                return { handled: true, message: "CORE GIMBAL ALIGNED. Type 'bankai' to release aggressive scan limits." }
            }
            return { handled: true, message: "Invocation out of sequence. Initiate style sun first." }
        }
        if (clean === "bankai") {
            if (authState === "shikai_aligned") {
                breathingStyle = "sun"
                authState = "idle"
                _notifyBackend("sun")
                return { handled: true, message: "⚔ BANKAI RELEASED. Resource ceilings expanded." }
            }
            return { handled: true, message: "Core alignment required. Type 'shikai' first." }
        }
        return { handled: false, message: "" }
    }

    function _notifyBackend(style) {
        var xhr = new XMLHttpRequest()
        xhr.open("POST", "http://127.0.0.1:8765/api/system/breathing-style")
        xhr.setRequestHeader("Content-Type", "application/json")
        xhr.send(JSON.stringify({ style: style }))
    }

    // ── System metrics (written by WebSocket pulse) ───────────────────
    property real   sysCpu:  0.0
    property real   sysRam:  0.0
    property real   sysTemp: 0.0
    property string governorFrequency: "—"
    property string daemonState: "checking"   // "alive" | "dead" | "checking"

    // ── Prismatic color — single source of truth ──────────────────────
    readonly property color prismaticColor: {
        var active = anticipatedStyle || breathingStyle
        if (active === "sun")       return Qt.color("#f43f5e")
        if (active === "moon")      return Qt.color("#00B4D8")
        if (active === "celestial") return Qt.color("#B44FE8")
        return Qt.color("#00B4D8")
    }

    // ── AI streaming state ────────────────────────────────────────────
    property bool   simStreaming: false
    property string simPhase:    "idle"   // "idle" | "recall" | "reason" | "respond"
    property string simLiveText: ""
    property var    simMessages: []

    function pushMessage(role, text) {
        var arr = simMessages.slice()
        arr.push({ role: role, text: text, ts: new Date().toLocaleTimeString() })
        if (arr.length > 40) arr = arr.slice(arr.length - 40)
        simMessages = arr
    }

    function clearMessages() {
        simMessages = []
        simLiveText = ""
        simStreaming = false
        simPhase = "idle"
    }

    // ── Locked recon target ───────────────────────────────────────────
    property string lockedTarget: ""

    // ── Keystroke APM ─────────────────────────────────────────────────
    property real apmHeat: 0.0
    property var  _keystrokeTimes: []

    function recordKeystroke() {
        var now = Date.now()
        _keystrokeTimes = _keystrokeTimes.filter(function(t) { return now - t < 2000 })
        _keystrokeTimes.push(now)
        apmHeat = Math.min(100, _keystrokeTimes.length * 5)
    }

    // ── Native command runner ─────────────────────────────────────────
    function runNativeCommand(cmd) {
        _cmdProc.command = ["/bin/bash", "-c", cmd]
        _cmdProc.running = true
    }

    function getCombinedCommand(currentQuery) {
        var cmdParts = []
        for (var i = 0; i < lockedChips.length; i++) {
            var chip = lockedChips[i]
            if (!chip.isStyle) {
                cmdParts.push(chip.cmd || chip.id)
            }
        }
        if (currentQuery && currentQuery.trim() !== "") {
            cmdParts.push(currentQuery.trim())
        }
        return cmdParts.join(" ").trim()
    }

    property Process _cmdProc: Process {
        id: _cmdProc
    }
}
