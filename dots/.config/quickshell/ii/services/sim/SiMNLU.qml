/* SiMNLU.qml — Natural Language Understanding (dots-hyprland port)
 * ==================================================================
 * DESTINATION: .config/quickshell/services/sim/SiMNLU.qml
 *
 * Ported from: soul/obelisk/runes/NLU.qml (DMS plugin)
 *
 * Singleton. Pure logic — no UI.
 * Intercepts input from the SiM command bar before it reaches
 * end4's normal launcher behavior.
 *
 * classify(input)        → intent object
 * isConversational(input) → bool
 * suggestions(query)     → array of portal pills
 * ghostText(query)       → string suffix
 * isSiMCommand(input)    → bool (true = handle in SiM, false = pass to end4)
 */
pragma Singleton
import QtQuick

QtObject {
    id: nlu

    // ── isSiMCommand ──────────────────────────────────────────────────
    // Gate: returns true if SiM should handle this input exclusively.
    // Returns false to pass through to end4's app search / AI sidebar.
    function isSiMCommand(input) {
        var q = (input || "").trim().toLowerCase()
        if (!q) return false

        // Breathing style commands
        if (q === "sun" || q === "moon" || q === "celestial" || q === "prismatic") return true
        if (q.startsWith("/style ") || q.startsWith("style ")) return true
        if (q === "shikai" || q === "bankai") return true

        // ROM invocations
        if (resolveRomAlias(q)) return true

        // Explicit SiM prefix
        if (q.startsWith("@") || q.startsWith("sim ")) return true

        // Shell commands → route to Conduit
        if (/^[\/~\$]/.test(q)) return true
        if (/^(sudo|nmap|amass|subfinder|recon-ng|dnsx|httpx|rustscan|nuclei|ffuf|gobuster|ghauri|curl|wget|git|python|node|bash|sh)\b/.test(q)) return true

        return false
    }

    // ── classify ──────────────────────────────────────────────────────
    function classify(input) {
        var q = (input || "").trim()
        var lower = q.toLowerCase()

        var intent = {
            confidence:    0.0,
            cmd:           "",
            isRom:         false,
            romId:         "",
            isConv:        false,
            originalInput: q,
            rune:          null
        }

        if (!q) return intent

        // ROM alias — highest priority
        var romId = resolveRomAlias(lower)
        if (romId) {
            intent.isRom = true
            intent.romId = romId
            intent.confidence = 0.97
            return intent
        }

        // Conversational
        if (isConversational(q)) {
            intent.isConv = true
            intent.confidence = 0.80
            return intent
        }

        // Shell command passthrough → Conduit
        if (/^[\/~\$]/.test(q) || /^(sudo|cd|ls|cat|grep|find|git|npm|pip|python|node|bash|sh|nmap|amass|subfinder|recon-ng|dnsx|httpx|rustscan|nuclei|ffuf|gobuster|ghauri)\b/.test(lower)) {
            intent.cmd = q
            intent.confidence = 0.90
            return intent
        }

        return intent
    }

    // ── ROM alias resolver ────────────────────────────────────────────
    readonly property var _romAliases: ({
        "conduit":  "conduit", "terminal": "conduit", "term": "conduit",
        "pty":      "conduit", "shell":    "conduit", "bash": "conduit",
        "simcomm":  "simcomm", "sim":      "simcomm", "ask":  "simcomm",
        "chat":     "simcomm", "ai":       "simcomm",
        "atelier":  "atelier", "workshop": "atelier", "forge": "atelier",
        "sibyls":   "atelier", "docker":   "atelier", "vault": "atelier",
        "grimoire": "grimoire","grim":     "grimoire","ide":   "grimoire",
        "editor":   "grimoire","code":     "grimoire",
        "ori":      "ori",     "browser":  "ori",     "web":   "ori"
    })

    function resolveRomAlias(input) {
        var q = (input || "").toLowerCase().trim()
        if (q.startsWith("@")) q = q.slice(1).trim() || "simcomm"
        return _romAliases[q] || null
    }

    // ── isConversational ──────────────────────────────────────────────
    function isConversational(input) {
        var q = (input || "").trim().toLowerCase()
        if (!q) return false
        if (q.startsWith("@") || q.startsWith("ask ") || q.startsWith("sim ")) return true
        if (q.endsWith("?") || q.endsWith("!")) return true
        var starters = [
            "what","how","why","who","when","where","can","is","are","does","do",
            "will","would","could","should","tell","show","explain","help","give",
            "find","list","check","get","make","create","build","write","analyze",
            "describe","hello","hey","hi","yes","no","ok","sure","thanks","please"
        ]
        for (var i = 0; i < starters.length; i++) {
            if (q.startsWith(starters[i])) return true
        }
        if (q.split(/\s+/).length >= 5) return true
        return false
    }

    // ── suggestions ───────────────────────────────────────────────────
    function suggestions(query, lockedTokens) {
        var q = (query || "").trim().toLowerCase()
        var results = []

        // Tool presets when a tool rune is locked
        if (lockedTokens && lockedTokens.length > 0) {
            var toolId = lockedTokens[0].id
            var presets = _toolPresets[toolId] || []
            for (var p = 0; p < presets.length; p++) {
                var pr = presets[p]
                if (q === "" || pr.label.toLowerCase().indexOf(q) !== -1) {
                    results.push({
                        category: "preset", id: pr.id, label: pr.label,
                        icon: pr.icon, color: pr.color, preview: pr.preview, isPreset: true
                    })
                }
            }
            if (results.length > 0) return results
        }

        if (q.length < 1) return results

        // ROM prefix match
        var roms = [
            { id: "conduit",  name: "Conduit",  icon: "⚔", color: "#FF3CAC" },
            { id: "simcomm",  name: "SiMComm",  icon: "◈", color: "#818cf8" },
            { id: "atelier",  name: "Atelier",  icon: "⬡", color: "#FF6B35" },
            { id: "grimoire", name: "Grimoire", icon: "⬡", color: "#FF6B35" },
            { id: "ori",      name: "Ori",      icon: "◉", color: "#00C2FF" }
        ]
        for (var i = 0; i < roms.length; i++) {
            if (roms[i].id.startsWith(q)) {
                results.push({
                    category: "rom", id: roms[i].id, label: roms[i].name,
                    icon: roms[i].icon, color: roms[i].color, preview: "open " + roms[i].name
                })
            }
        }

        // Breathing style prefix
        var styles = [
            { id: "sun",       icon: "☀", color: "#f59e0b" },
            { id: "moon",      icon: "☽", color: "#818cf8" },
            { id: "celestial", icon: "✧", color: "#ffffff" }
        ]
        for (var si = 0; si < styles.length; si++) {
            if (styles[si].id.startsWith(q) && q.length >= 2) {
                results.push({
                    category: "style", id: "~" + styles[si].id, label: styles[si].id,
                    icon: styles[si].icon, color: styles[si].color,
                    preview: styles[si].id + " breathing"
                })
            }
        }

        var seen = {}, deduped = []
        for (var di = 0; di < results.length; di++) {
            if (!seen[results[di].id]) { seen[results[di].id] = true; deduped.push(results[di]) }
        }
        return deduped.slice(0, 6)
    }

    // ── ghostText ─────────────────────────────────────────────────────
    function ghostText(query) {
        if (!query) return ""
        var q = query.trim().toLowerCase()
        var roms = ["conduit","simcomm","atelier","grimoire","ori"]
        for (var i = 0; i < roms.length; i++) {
            if (roms[i].startsWith(q) && roms[i] !== q) return roms[i].slice(q.length)
        }
        var styles = ["sun","moon","celestial"]
        for (var si = 0; si < styles.length; si++) {
            if (styles[si].startsWith(q) && styles[si] !== q) return styles[si].slice(q.length)
        }
        if (q.length >= 3 && isConversational(q)) return " → SiM"
        return ""
    }

    // ── Tool presets ──────────────────────────────────────────────────
    readonly property var _toolPresets: ({
        "nmap": [
            { id: "nmap_quick", label: "Quick Scan",  preview: "nmap -sV -sC -T4",      icon: "⊕", color: "#22d3ee" },
            { id: "nmap_vuln",  label: "Vuln Scan",   preview: "nmap --script vuln",     icon: "⊕", color: "#22d3ee" },
            { id: "nmap_full",  label: "Full Scan",   preview: "nmap -p- -T4",           icon: "⊕", color: "#22d3ee" }
        ],
        "nuclei": [
            { id: "nuclei_cves", label: "CVEs Only",  preview: "nuclei -t cves/",              icon: "⚔", color: "#f43f5e" },
            { id: "nuclei_crit", label: "Critical",   preview: "nuclei -severity critical",    icon: "⚔", color: "#f43f5e" },
            { id: "nuclei_tech", label: "Tech Scan",  preview: "nuclei -t technologies/",      icon: "⚔", color: "#f43f5e" }
        ],
        "subfinder": [
            { id: "sub_silent", label: "Silent Recon",   preview: "subfinder -silent",  icon: "⊕", color: "#22d3ee" },
            { id: "sub_active", label: "Active Resolve", preview: "subfinder -active",  icon: "⊕", color: "#22d3ee" }
        ],
        "amass": [
            { id: "amass_passive", label: "Passive Enum", preview: "amass enum -passive", icon: "⊕", color: "#22d3ee" },
            { id: "amass_active",  label: "Active Enum",  preview: "amass enum -active",  icon: "⊕", color: "#22d3ee" }
        ],
        "httpx": [
            { id: "httpx_status", label: "Status Check",  preview: "httpx -status-code", icon: "⊕", color: "#22d3ee" },
            { id: "httpx_title",  label: "Extract Title", preview: "httpx -title",        icon: "⊕", color: "#22d3ee" }
        ],
        "rustscan": [
            { id: "rust_quick", label: "Quick Port Scan", preview: "rustscan -a", icon: "⚡", color: "#00B4D8" }
        ],
        "ffuf": [
            { id: "ffuf_common", label: "Common Fuzz", preview: "ffuf -w wordlist.txt -u", icon: "⬡", color: "#9B1FA0" }
        ],
        "gobuster": [
            { id: "gobust_dir", label: "Dir Buster", preview: "gobuster dir -w wordlist.txt -u", icon: "⬡", color: "#9B1FA0" }
        ],
        "ghauri": [
            { id: "ghauri_auto", label: "Automated SQLi", preview: "ghauri --dbs --batch -u", icon: "⚔", color: "#f43f5e" }
        ]
    })
}
