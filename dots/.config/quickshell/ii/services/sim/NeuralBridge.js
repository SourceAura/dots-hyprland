/* NeuralBridge.js — SiM Inference Router
 * ==========================================
 * Three-tier routing for the Obelisk's conversational path.
 *
 * Tier 1 — Reflex  (default):  qwen2.5-coder:1.5b via local Ollama
 * Tier 2 — Analytic (complex): qwen2.5-coder:7b-q4 via local Ollama
 * Tier 3 — Cloud   (@cloud):   Nemotron via OpenRouter
 *
 * All tiers route through the SiM backend WebSocket at :8765.
 * The backend handles tier selection based on prompt prefix + hardware state.
 *
 * Usage:
 *   NeuralBridge.ask(config, prompt, onToken, onDone, onError)
 *
 * Routing prefixes (passed transparently to backend):
 *   @analytic <query>  — force Analytic Core (7b, plugged-in only)
 *   @cloud <query>     — force Cloud (Nemotron via OpenRouter)
 *   <query>            — auto-select (Reflex by default)
 */

const WS_URL = "ws://127.0.0.1:8765/intelligence-feed"

/**
 * ask() — send a query through the SiM backend WebSocket.
 *
 * @param {object}   config   - The config containing stealth, keys, etc.
 * @param {string}   prompt   - The user query (may include @analytic/@cloud prefix)
 * @param {function} onToken  - called with each streamed token string
 * @param {function} onDone   - called when stream completes
 * @param {function} onError  - called with error string on failure
 */
function ask(config, prompt, onToken, onDone, onError) {
    var ws = Qt.createQmlObject('import QtWebSockets; WebSocket {}', Qt.application)
    var done = false

    ws.url = WS_URL
    ws.active = true

    ws.statusChanged.connect(function() {
        var statusOpen = (typeof WebSocket !== 'undefined') ? WebSocket.Open : 1;
        var statusClosed = (typeof WebSocket !== 'undefined') ? WebSocket.Closed : 3;
        var statusError = (typeof WebSocket !== 'undefined') ? WebSocket.Error : 4;

        if (ws.status === statusOpen) {
            ws.sendTextMessage(JSON.stringify({
                type:            "SIM_QUERY",
                message:         prompt,
                focused_rom:     (config && config.active_rom) || "none",
                breathing_style: (config && config.breathing_style) || "moon",
                stealth:         (config && config.stealth) || false,
                groq_key:        (config && config.groqKey) || "",
                gemini_key:      (config && config.geminiKey) || ""
            }))
        } else if (ws.status === statusError) {
            if (!done) {
                done = true
                onError("WebSocket error — is the SiM daemon running?")
                ws.destroy()
            }
        } else if (ws.status === statusClosed) {
            if (!done) {
                done = true
                onError("Connection closed before response completed.")
                ws.destroy()
            }
        }
    })

    ws.textMessageReceived.connect(function(message) {
        try {
            var d = JSON.parse(message)
            var t = d.type || ""

            if (t === "STREAM_TOKEN") {
                if (d.token) onToken(d.token)
            } else if (t === "STREAM_END" || t === "SIM_RESPONSE") {
                if (!done) {
                    done = true
                    onDone()
                    ws.destroy()
                }
            } else if (t === "INFERENCE_START" || t === "THINKING_PHASE") {
                // Phase signals — caller handles via SiMOrchestrator
            }
        } catch(e) {}
    })
}

/**
 * ping() — check if the backend is alive.
 * @param {function} onAlive  - called if backend responds
 * @param {function} onDead   - called if connection fails
 */
function ping(onAlive, onDead) {
    var ws = Qt.createQmlObject('import QtWebSockets; WebSocket {}', Qt.application)
    var resolved = false

    ws.url = WS_URL
    ws.active = true

    ws.statusChanged.connect(function() {
        var statusOpen = (typeof WebSocket !== 'undefined') ? WebSocket.Open : 1;
        var statusClosed = (typeof WebSocket !== 'undefined') ? WebSocket.Closed : 3;
        var statusError = (typeof WebSocket !== 'undefined') ? WebSocket.Error : 4;

        if (ws.status === statusOpen) {
            ws.sendTextMessage(JSON.stringify({ type: "PING" }))
        } else if (ws.status === statusError || ws.status === statusClosed) {
            if (!resolved) {
                resolved = true
                onDead()
                ws.destroy()
            }
        }
    })

    ws.textMessageReceived.connect(function(message) {
        if (!resolved) {
            resolved = true
            onAlive()
            ws.destroy()
        }
    })

    // Timeout after 2s
    var timer = Qt.createQmlObject('import QtQuick; Timer { interval: 2000; repeat: false }', Qt.application)
    timer.triggered.connect(function() {
        if (!resolved) {
            resolved = true
            onDead()
            ws.destroy()
        }
        timer.destroy()
    })
    timer.start()
}
