/* SiMRunes.qml — Rune Registry (dots-hyprland port)
 * ==================================================================
 * DESTINATION: .config/quickshell/services/sim/SiMRunes.qml
 *
 * Ported from: soul/obelisk/runes/RuneRegistry.qml (DMS plugin)
 *
 * Singleton. Defines all tool runes available in the SiM command bar.
 * Each rune is a Tab-lockable token that stages a tool invocation.
 *
 * Folds:
 *   EYE    — recon tools (nmap, subfinder, amass, dnsx, httpx, rustscan)
 *   BLADE  — offensive tools (nuclei, ffuf, gobuster, ghauri, sqlmap)
 *   SHROUD — anonymity tools (proxychains, tor, curl --proxy)
 *   FORGE  — build/assembly tools (git, docker, cargo, npm)
 *   SAGE   — analysis tools (grep, awk, jq, python)
 */
pragma Singleton
import QtQuick

QtObject {
    id: registry

    readonly property var runes: [
        // ── EYE fold — Recon ─────────────────────────────────────────
        { id: "nmap",      label: "nmap",      icon: "◉", color: "#00C2FF", fold: "eye",    cmd: "nmap",      terminal: true  },
        { id: "subfinder", label: "subfinder", icon: "◉", color: "#00C2FF", fold: "eye",    cmd: "subfinder", terminal: true  },
        { id: "amass",     label: "amass",     icon: "◉", color: "#00C2FF", fold: "eye",    cmd: "amass",     terminal: true  },
        { id: "dnsx",      label: "dnsx",      icon: "◉", color: "#00C2FF", fold: "eye",    cmd: "dnsx",      terminal: true  },
        { id: "httpx",     label: "httpx",     icon: "◉", color: "#00C2FF", fold: "eye",    cmd: "httpx",     terminal: true  },
        { id: "rustscan",  label: "rustscan",  icon: "⚡", color: "#00B4D8", fold: "eye",    cmd: "rustscan",  terminal: true  },
        { id: "recon-ng",  label: "recon-ng",  icon: "◉", color: "#00C2FF", fold: "eye",    cmd: "recon-ng",  terminal: true  },

        // ── BLADE fold — Offensive ────────────────────────────────────
        { id: "nuclei",    label: "nuclei",    icon: "⚔", color: "#FF3CAC", fold: "blade",  cmd: "nuclei",    terminal: true  },
        { id: "ffuf",      label: "ffuf",      icon: "⚔", color: "#FF3CAC", fold: "blade",  cmd: "ffuf",      terminal: true  },
        { id: "gobuster",  label: "gobuster",  icon: "⚔", color: "#FF3CAC", fold: "blade",  cmd: "gobuster",  terminal: true  },
        { id: "ghauri",    label: "ghauri",    icon: "⚔", color: "#FF3CAC", fold: "blade",  cmd: "ghauri",    terminal: true  },
        { id: "sqlmap",    label: "sqlmap",    icon: "⚔", color: "#FF3CAC", fold: "blade",  cmd: "sqlmap",    terminal: true  },

        // ── SHROUD fold — Anonymity ───────────────────────────────────
        { id: "proxychains", label: "proxychains", icon: "☁", color: "#00FFC8", fold: "shroud", cmd: "proxychains", terminal: true },
        { id: "torify",    label: "torify",    icon: "☁", color: "#00FFC8", fold: "shroud", cmd: "torify",    terminal: true  },

        // ── FORGE fold — Build ────────────────────────────────────────
        { id: "git",       label: "git",       icon: "⬡", color: "#FF6B35", fold: "forge",  cmd: "git",       terminal: true  },
        { id: "docker",    label: "docker",    icon: "🐳", color: "#FF6B35", fold: "forge",  cmd: "docker",    terminal: true  },
        { id: "cargo",     label: "cargo",     icon: "⬡", color: "#FF6B35", fold: "forge",  cmd: "cargo",     terminal: true  },
        { id: "npm",       label: "npm",       icon: "⬡", color: "#FF6B35", fold: "forge",  cmd: "npm",       terminal: true  },

        // ── SAGE fold — Analysis ──────────────────────────────────────
        { id: "python",    label: "python",    icon: "◈", color: "#FFB300", fold: "sage",   cmd: "python",    terminal: true  },
        { id: "jq",        label: "jq",        icon: "◈", color: "#FFB300", fold: "sage",   cmd: "jq",        terminal: false },
        { id: "grep",      label: "grep",      icon: "◈", color: "#FFB300", fold: "sage",   cmd: "grep",      terminal: false }
    ]

    function resolve(id) {
        for (var i = 0; i < runes.length; i++)
            if (runes[i].id === id) return runes[i]
        return null
    }

    function match(input) {
        var q = (input || "").trim().toLowerCase()
        for (var i = 0; i < runes.length; i++)
            if (runes[i].id === q || runes[i].cmd === q) return runes[i]
        return null
    }

    function byFold(fold) {
        return runes.filter(function(r) { return r.fold === fold })
    }
}
