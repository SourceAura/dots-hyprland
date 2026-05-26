"""
breathing.py — SiM Breathing Style system.
Three progenitor styles only: Sun, Moon, Celestial (Star).
"""
from __future__ import annotations
from dataclasses import dataclass
from typing import Optional


@dataclass
class BreathingStyle:
    name:          str
    display_name:  str
    color:         str
    icon:          str
    description:   str
    system_prompt: str


STYLES: dict[str, BreathingStyle] = {
    "sun": BreathingStyle(
        name="sun",
        display_name="Sun Breathing",
        color="#f43f5e", # Strike-Rose Red
        icon="☀",
        description="Sovereign authority — decisive, high-confidence operations.",
        system_prompt=(
            "Sun Breathing: Progenitor of action. Command with absolute clarity. "
            "No hedging. Be the center of gravity."
        ),
    ),
    "moon": BreathingStyle(
        name="moon",
        display_name="Moon Breathing",
        color="#00B4D8", # Cerulean
        icon="☽",
        description="Deep analysis — system introspection and synthesis.",
        system_prompt=(
            "Moon Breathing: Progenitor of thought. Synthesize deep system layers. "
            "Perceive the hidden structure."
        ),
    ),
    "celestial": BreathingStyle(
        name="celestial",
        display_name="Celestial Breathing",
        color="#ffffff",
        icon="✧",
        description="Autonomous zenith — multi-vector synchronization.",
        system_prompt=(
            "Celestial Breathing: The Autonomous Zenith. Navigate multi-vector complexity. "
            "Synchronize all dimensions. Be the North Star."
        ),
    ),
}

_active: BreathingStyle = STYLES["moon"]


def get_style() -> BreathingStyle:
    return _active


def set_style(name: str) -> Optional[BreathingStyle]:
    global _active
    style = STYLES.get(name.lower().strip())
    if not style:
        return None
    _active = style
    _inject(style)
    return style


def list_styles() -> list[dict]:
    return [
        {"name": s.name, "display_name": s.display_name,
         "color": s.color, "icon": s.icon, "description": s.description}
        for s in STYLES.values()
    ]


def _inject(style: BreathingStyle) -> None:
    """Push style system prompt into CognitiveManager if ready."""
    try:
        from ai.manager import cognitive_manager
        if cognitive_manager.llm:
            cognitive_manager._active_style_prompt = style.system_prompt
    except Exception:
        pass
