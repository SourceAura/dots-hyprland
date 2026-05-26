#!/usr/bin/env bash
# =============================================================================
# fresh_install.sh — SiM Complete Fresh Installation & Compilation Suite
# =============================================================================
# The ultimate one-liner installation script that:
#   1. Detects live config & local git repositories.
#   2. Deploys all services/sim/, modules/sim/, and core/ daemons.
#   3. Automatedly patches shell.qml in all targets safely.
#   4. Bootstraps the Python virtual environment and installs requirements.
#   5. Compiles Rust governor & kasugai components in release mode.
#   6. Installs and links custom Hyprland keybindings.
# =============================================================================
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

log_ok()   { echo -e "  ${GREEN}[✓]${NC} $*"; }
log_warn() { echo -e "  ${YELLOW}[!]${NC} $*"; }
log_err()  { echo -e "  ${RED}[✗]${NC} $*" >&2; }
log_info() { echo -e "  ${CYAN}[-]${NC} $*"; }
log_step() { echo -e "\n${BOLD}${CYAN}▶  $*${NC}"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SIM_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# ── Auto-Detect Targets ───────────────────────────────────────────────
LIVE_QS_ROOT="$HOME/.config/quickshell/ii"
GIT_QS_ROOT="$HOME/Documents/GitHub/dots-hyprland/dots/.config/quickshell/ii"

TARGET_DIRS=()
if [[ -d "${LIVE_QS_ROOT}" ]]; then
    TARGET_DIRS+=("${LIVE_QS_ROOT}")
fi
if [[ -d "${GIT_QS_ROOT}" ]]; then
    TARGET_DIRS+=("${GIT_QS_ROOT}")
fi

if [[ ${#TARGET_DIRS[@]} -eq 0 ]]; then
    log_err "No quickshell directories found! Checked active (~/.config/quickshell/ii) and git clone."
    exit 1
fi

echo -e "\n${BOLD}${CYAN}◈  SiM Complete Fresh Installation Suite${NC}"
echo -e "  Source:  ${SIM_ROOT}"
for TARGET in "${TARGET_DIRS[@]}"; do
    echo -e "  Target:  ${TARGET}"
done

# ── 1. Deploy File Layers ─────────────────────────────────────────────
for QS_ROOT in "${TARGET_DIRS[@]}"; do
    log_step "Deploying components into ${QS_ROOT}"

    # Services
    mkdir -p "${QS_ROOT}/services/sim"
    cp -r "${SCRIPT_DIR}/services/sim/." "${QS_ROOT}/services/sim/"
    log_ok "Services layer synced."

    # Modules
    mkdir -p "${QS_ROOT}/modules/sim"
    cp -r "${SCRIPT_DIR}/modules/sim/." "${QS_ROOT}/modules/sim/"
    log_ok "Modules layer synced."

    # Backend
    if [[ ! -d "${QS_ROOT}/core" ]]; then
        cp -r "${SIM_ROOT}/core" "${QS_ROOT}/core"
        log_ok "Core backend synced."
    else
        log_warn "Core directory already exists — keeping active version."
    fi

    # Configs
    if [[ ! -f "${QS_ROOT}/Modelfile" ]]; then cp "${SIM_ROOT}/Modelfile" "${QS_ROOT}/Modelfile"; fi
    if [[ ! -f "${QS_ROOT}/.env" ]]; then cp "${SIM_ROOT}/.env" "${QS_ROOT}/.env"; fi

    # ── 2. Automated shell.qml Patcher ────────────────────────────────
    SHELL_QML="${QS_ROOT}/shell.qml"
    if [[ -f "${SHELL_QML}" ]]; then
        if grep -q "SiMSovereign" "${SHELL_QML}"; then
            log_ok "shell.qml already patched with SiM overlays."
        else
            log_info "Patching shell.qml with SiM overlays..."
            # Insert imports at the top
            sed -i 's|import "services"|import "services"\nimport "services/sim" as SiM\nimport "modules/sim" as SiMModules|g' "${SHELL_QML}"
            
            # Insert ROM loader and IPC handler before the final closing brace
            # We locate the last brace using python or bash string manipulation
            python3 -c "
with open('${SHELL_QML}', 'r') as f:
    content = f.read()
if '_simRomLoader' not in content:
    idx = content.rfind('}')
    patch = '''
    // ── SiM ROM overlay ──────────────────────────────────────────────────
    // Loads the active ROM as a WlrLayer.Overlay panel.
    // Active only when a ROM is open — zero cost otherwise.
    Loader {
        id: _simRomLoader
        active:  SiM.SiMSovereign.activeRom !== \"\"
        source:  SiM.SiMSovereign.romPath
        visible: active
    }

    // ── SiM IPC Handler ──────────────────────────────────────────────────
    IpcHandler {
        target: \"SiMSovereign\"

        function toggleRom(id: string): void {
            SiM.SiMSovereign.toggleRom(id)
        }

        function processCommand(cmd: string): void {
            SiM.SiMSovereign.processCommand(cmd)
        }
    }
'''
    new_content = content[:idx] + patch + content[idx:]
    with open('${SHELL_QML}', 'w') as f:
        f.write(new_content)
"
            log_ok "shell.qml successfully patched!"
        fi
    fi

    # ── 3. Keybindings Patching ───────────────────────────────────────
    if [[ "${QS_ROOT}" == *"/quickshell/ii" ]]; then
        HYPR_DIR="$HOME/.config/hypr"
    else
        HYPR_DIR="$(dirname "$(dirname "$(dirname "${QS_ROOT}")")")/hypr"
    fi

    if [[ -d "${HYPR_DIR}" ]]; then
        cp "${SCRIPT_DIR}/KEYBINDS_PATCH.conf" "${HYPR_DIR}/sim-keybinds.conf"
        KEYBINDS_MAIN="${HYPR_DIR}/keybinds.conf"
        if [[ -f "${KEYBINDS_MAIN}" ]]; then
            if ! grep -q "sim-keybinds.conf" "${KEYBINDS_MAIN}"; then
                echo -e "\nsource = ~/.config/hypr/sim-keybinds.conf" >> "${KEYBINDS_MAIN}"
                log_ok "Keybinds wired into ${KEYBINDS_MAIN}."
            else
                log_ok "Keybinds already linked."
            fi
        fi
    fi
done

# ── 4. Python Virtual Environment Setup ───────────────────────────────
log_step "Setting up Python virtual environment"
PRIMARY_CORE="${LIVE_QS_ROOT}/core"
if [[ -d "${PRIMARY_CORE}" ]]; then
    cd "${PRIMARY_CORE}"
    if [[ ! -d "venv" ]]; then
        python3 -m venv venv
        log_ok "Virtual environment created."
    fi
    log_info "Installing Python dependencies..."
    ./venv/bin/pip install --quiet --upgrade pip
    ./venv/bin/pip install --quiet -r requirements.txt
    log_ok "Dependencies installed successfully."
fi

# ── 5. Compile Rust Bridges ───────────────────────────────────────────
log_step "Compiling Rust bridges (Governor & Kasugai Substrate)"
if command -v cargo &>/dev/null; then
    # Governor Build
    GOV_DIR="${PRIMARY_CORE}/bridge/governor/governor"
    if [[ -d "${GOV_DIR}" ]]; then
        log_info "Building Governor..."
        cd "${GOV_DIR}"
        cargo build --release --quiet
        log_ok "sim-governor successfully built."
    fi

    # Kasugai Build
    KAS_DIR="${PRIMARY_CORE}/bridge/kasugai"
    if [[ -d "${KAS_DIR}" ]]; then
        log_info "Building Kasugai Substrate..."
        cd "${KAS_DIR}"
        cargo build --release --quiet
        log_ok "kasugai successfully built."
    fi
else
    log_warn "Rust (cargo) not found — skipping bridges compilation."
fi

# ── 6. Verification and Ignition ──────────────────────────────────────
log_step "Ignition Verification"
IGNITION_SCRIPT="${PRIMARY_CORE}/scripts/sim.sh"
if [[ -f "${IGNITION_SCRIPT}" ]]; then
    log_ok "Installation finished! Triggering core services ignition..."
    bash "${IGNITION_SCRIPT}" ignite
else
    log_warn "Ignition script not found."
fi

echo -e "\n${BOLD}${GREEN}◈  SiM Fresh Installation Complete!${NC}"
echo -e "  Launcher integrated, keybindings linked, Rust bridges compiled, and daemon online."
echo -e "  Open the Overview launcher with ${CYAN}SUPER${NC} key and type ${CYAN}moon${NC} to start.\n"
