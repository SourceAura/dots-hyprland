hl.bind("CTRL+SUPER+ALT+Slash", hl.dsp.exec_cmd("xdg-open ~/.config/hypr/custom/keybinds.lua"), {description = "Edit user keybinds"} )

-- ── SiM Sovereign keybinds ──────────────────────────────────────────
hl.bind("SUPER+Space", hl.dsp.exec_cmd("/usr/sbin/qs -c ii ipc call sidebarLeft openIntelligence"), {description = "Toggle SiM Tab"})

-- ── ROM overlays ─────────────────────────────────────────────────────
hl.bind("SUPER+SHIFT+Z", hl.dsp.exec_cmd("/usr/sbin/qs -c ii ipc call SiMSovereign toggleRom conduit"), {description = "Toggle Conduit ROM"})
hl.bind("SUPER+SHIFT+W", hl.dsp.exec_cmd("/usr/sbin/qs -c ii ipc call SiMSovereign toggleRom atelier"), {description = "Toggle Atelier ROM"})
hl.bind("SUPER+SHIFT+K", hl.dsp.exec_cmd("/usr/sbin/qs -c ii ipc call SiMSovereign toggleRom grimoire"), {description = "Toggle Grimoire ROM"})
hl.bind("SUPER+SHIFT+U", hl.dsp.exec_cmd("/usr/sbin/qs -c ii ipc call SiMSovereign toggleRom ori"), {description = "Toggle Ori ROM"})
hl.bind("SUPER+SHIFT+I", hl.dsp.exec_cmd("/usr/sbin/qs -c ii ipc call SiMSovereign toggleRom simcomm"), {description = "Toggle SiMComm ROM"})

-- ── Breathing style shortcuts ─────────────────────────────────────────
hl.bind("SUPER+SHIFT+J", hl.dsp.exec_cmd("/usr/sbin/qs -c ii ipc call SiMSovereign processCommand moon"), {description = "Moon Breathing Mode"})
hl.bind("SUPER+SHIFT+H", hl.dsp.exec_cmd("/usr/sbin/qs -c ii ipc call SiMSovereign processCommand celestial"), {description = "Prismatic Breathing Mode"})

-- ── Backend daemon ────────────────────────────────────────────────────
hl.bind("SUPER+SHIFT+BackSpace", hl.dsp.exec_cmd("bash ~/.config/quickshell/ii/core/scripts/sim.sh status"), {description = "Check Backend status"})

