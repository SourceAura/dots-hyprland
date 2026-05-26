/* Folds.js — The 7 Sibyls of SiM
 * ==============================================
 * Central metadata for the 7 folds and their domains.
 */
.pragma library

const DATA = {
    "eye": {
        id: "eye",
        icon: "◉",
        domain: "Recon & Intelligence",
        principle: "TRUTH",
        purpose: "Zero-hallucination data integrity. Information gathering, scanning, discovery.",
        accent: "#00C2FF"
    },
    "phantom": {
        id: "phantom",
        icon: "⊗",
        domain: "Deception & Evasion",
        principle: "POWER",
        purpose: "Stealth, hiding tracks, false operations. System owns the metal.",
        accent: "#B44FE8"
    },
    "blade": {
        id: "blade",
        icon: "⚔",
        domain: "Offensive Operations",
        principle: "WISDOM",
        purpose: "Direct attacks, exploits, engagement. Esoteric logic mastery.",
        accent: "#FF3CAC"
    },
    "sage": {
        id: "sage",
        icon: "◈",
        domain: "Knowledge & Wisdom",
        principle: "JUDGMENT",
        purpose: "Autonomous threat assessment. AI analysis, insights, learning.",
        accent: "#FFB300"
    },
    "shroud": {
        id: "shroud",
        icon: "☁",
        domain: "Privacy & Anonymity",
        principle: "LIFE",
        purpose: "Tunneling, encryption, protection. Daemon never sleeps.",
        accent: "#00FFC8"
    },
    "forge": {
        id: "forge",
        icon: "⬡",
        domain: "Creation & Assembly",
        principle: "LOVE",
        purpose: "Building tools, kill chains, preparation. Absolute loyalty.",
        accent: "#FF6B35"
    },
    "mirror": {
        id: "mirror",
        icon: "◌",
        domain: "Reflection & Duplication",
        principle: "DISCIPLINE",
        purpose: "Stealth and efficiency. No visual bloat. Copying, simulation.",
        accent: "#C8B8FF"
    }
};

function get(id) {
    return DATA[id] || null;
}

function getAll() {
    return Object.values(DATA);
}
