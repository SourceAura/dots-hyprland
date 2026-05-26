/* TransparentWorld.qml — SiM Visual Substrate
 * =============================================
 * Single source of truth for all visual tokens.
 * 透き通る世界 — depth through shadow, never blur.
 * Sharp borders. Bioluminescent accents. Obsidian depth.
 */
pragma Singleton
import QtQuick

QtObject {
    id: theme

    // ── Glass substrate ───────────────────────────────────────────────
    readonly property color glassBase:      Qt.rgba(0.039, 0.039, 0.047, 0.72)
    readonly property color glassBaseDense: Qt.rgba(0.039, 0.039, 0.047, 0.92)
    readonly property color glassBaseSolid: Qt.rgba(0.016, 0.016, 0.020, 0.97)
    readonly property int   glassRadius:      12
    readonly property int   glassRadiusLarge: 16
    readonly property int   glassRadiusSmall:  8

    // ── Shadow tokens — depth through shadow, never blur ─────────────
    readonly property real shadowBlur:    0.85
    readonly property int  shadowOffsetY: 6
    readonly property real shadowAlpha:   0.25

    // ── Typography ────────────────────────────────────────────────────
    readonly property string fontFamily:     "3270 Nerd Font Mono, Fira Code, monospace"
    readonly property string fontFamilyMono: "3270 Nerd Font Mono, Fira Code, monospace"
    readonly property int fontSizeMicro:  9
    readonly property int fontSizeLabel: 12
    readonly property int fontSizeBase:  14
    readonly property int fontSizeTitle: 16

    // ── Animation durations ───────────────────────────────────────────
    readonly property int colorTransition: 300
    readonly property int fadeTransition:  200
    readonly property int snapTransition:  120

    // ── Accent palette — the 7 Sibyls ────────────────────────────────
    readonly property color accentEye:      "#00C2FF"   // TRUTH
    readonly property color accentPhantom:  "#B44FE8"   // POWER
    readonly property color accentBlade:    "#FF3CAC"   // WISDOM
    readonly property color accentSage:     "#FFB300"   // JUDGMENT
    readonly property color accentShroud:   "#00FFC8"   // LIFE
    readonly property color accentForge:    "#FF6B35"   // LOVE
    readonly property color accentMirror:   "#C8B8FF"   // DISCIPLINE

    // Semantic
    readonly property color accentOk:     "#4ade80"
    readonly property color accentWarn:   "#fbbf24"
    readonly property color accentBreach: "#f43f5e"

    // Breathing styles
    readonly property var styleAccents: ({
        "sun":       "#f59e0b",
        "moon":      "#818cf8",
        "celestial": "#ffffff"
    })

    // ── Surface helpers ───────────────────────────────────────────────
    readonly property color shimmerTop:    Qt.rgba(1, 1, 1, 0.055)
    readonly property color divider:       Qt.rgba(1, 1, 1, 0.07)
    readonly property color textPrimary:   Qt.rgba(0.90, 0.95, 1.00, 0.88)
    readonly property color textSecondary: Qt.rgba(0.80, 0.88, 0.95, 0.45)
    readonly property color textDim:       Qt.rgba(0.75, 0.85, 0.92, 0.22)

    // ── glassShadow helper ────────────────────────────────────────────
    function glassShadow(accentColor, intensity) {
        var c = Qt.color(accentColor)
        var a = (intensity !== undefined) ? intensity : shadowAlpha
        return Qt.rgba(c.r, c.g, c.b, a)
    }

    // ── lexHighlight — terminal/chat output colorizer ─────────────────
    // Strips ANSI, applies semantic color spans for IPs, CVEs, sigils, etc.
    function lexHighlight(raw, lockedTarget) {
        if (!raw) return ""
        // Strip ANSI escape codes
        var s = raw.replace(/\x1b\[[0-9;]*m/g, "")
        s = s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")

        // IPs
        s = s.replace(/\b(\d{1,3}(?:\.\d{1,3}){3}(?::\d+)?)\b/g, function(m) {
            var col = (lockedTarget && m.startsWith(lockedTarget)) ? "#00B4D8" : "#C8E1DC"
            return '<font color="' + col + '"><b>' + m + '</b></font>'
        })
        // Ports
        s = s.replace(/\b(\d{1,5})\/(tcp|udp|open|closed|filtered)\b/gi,
            '<font color="#67E8F9"><b>$1/$2</b></font>')
        // CVEs
        s = s.replace(/\b(CVE-\d{4}-\d{4,7})\b/g,
            '<font color="#F59E0B"><b>$1</b></font>')
        // Severity
        s = s.replace(/\b(CRITICAL)\b/g, '<font color="#F43F5E"><b>$1</b></font>')
        s = s.replace(/\b(HIGH)\b/g,     '<font color="#FB923C"><b>$1</b></font>')
        s = s.replace(/\b(MEDIUM)\b/g,   '<font color="#FCD34D"><b>$1</b></font>')
        // Tool sigils
        s = s.replace(/\[(\+)\]/g, '<font color="#86EFAC"><b>[+]</b></font>')
        s = s.replace(/\[(-)\]/g,  '<font color="#F87171"><b>[-]</b></font>')
        s = s.replace(/\[(!)\]/g,  '<font color="#FCD34D"><b>[!]</b></font>')
        s = s.replace(/\[(\*)\]/g, '<font color="#67E8F9"><b>[*]</b></font>')
        // Paths
        s = s.replace(/((?:\/|~)[a-zA-Z0-9_.~\-]+(?:\/[a-zA-Z0-9_.~\-]+)*)/g,
            '<font color="#D7CDE1"><i>$1</i></font>')
        // Success/error keywords
        s = s.replace(/\b(SUCCESS|OK|DONE|UP|PASS|OPEN|ACTIVE)\b/g,
            '<font color="#BED7C3"><b>$1</b></font>')
        s = s.replace(/\b(ERROR|FAIL|DENIED|FATAL|DOWN|KILLED)\b/gi,
            '<font color="#F43F5E"><b>$1</b></font>')
        return s
    }
}
