# core/ai/discovery.py
# Sun iN Moon (SiM) — Active Dependency Discovery & Auto-Installation

import os
import shutil
import logging
from typing import List, Dict

logger = logging.getLogger("sim.discovery")

REQUIRED_TOOLS = {
    "nmap": {
        "pacman": "nmap",
        "description": "Network discovery & security auditing",
        "icon": "◉"
    },
    "amass": {
        "pacman": "amass",
        "description": "In-depth DNS enumeration and network mapping",
        "icon": "◈"
    },
    "subfinder": {
        "pacman": "subfinder",
        "description": "Subdomain discovery tool",
        "icon": "☁"
    },
    "nuclei": {
        "pacman": "nuclei",
        "description": "Fast and customizable vulnerability scanner",
        "icon": "⚔"
    },
    "htb-toolkit": {
        "aur": "htb-toolkit-git",
        "pip": "htb-toolkit",
        "description": "Hack The Box platform integration utility",
        "icon": "⬡"
    }
}

NOTIF_PATH = "/tmp/sim-notifications.log"

def scan_dependencies() -> Dict[str, bool]:
    """Check standard paths for security dependencies and notify operator of missing tools."""
    status = {}
    missing = []
    
    for tool, info in REQUIRED_TOOLS.items():
        exists = shutil.which(tool) is not None
        status[tool] = exists
        if not exists:
            missing.append(tool)
            
    if missing:
        logger.info(f"Discovery: Missing tools detected: {missing}")
        trigger_operator_notification(missing)
        
    return status

def trigger_operator_notification(missing_tools: List[str]):
    """Write formatted notification lines to the /tmp/sim-notifications.log for DMS ingestion."""
    try:
        with open(NOTIF_PATH, "a") as f:
            for tool in missing_tools:
                info = REQUIRED_TOOLS[tool]
                icon = info["icon"]
                desc = info["description"]
                # Format: LEVEL|TITLE|MESSAGE|ICON
                f.write(f"warning|Missing Tool: {tool}|{desc} is not installed. Type 'install {tool}' to install.|{icon}\n")
    except Exception as e:
        logger.error(f"Discovery: Failed to write system notification: {e}")

def get_install_command(tool: str) -> str:
    """Return the correct Arch pacman/AUR/pip installation command for a missing tool."""
    tool = tool.lower().strip()
    if tool not in REQUIRED_TOOLS:
        return ""
        
    info = REQUIRED_TOOLS[tool]
    if "pacman" in info:
        return f"sudo pacman -S --noconfirm {info['pacman']}"
    elif "aur" in info:
        return f"yay -S --noconfirm {info['aur']}"
    elif "pip" in info:
        return f"pip install {info['pip']}"
        
    return ""
