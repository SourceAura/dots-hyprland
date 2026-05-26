/// governor.rs — Equivalent Exchange Governor logic
///
/// Reads thermals, load, and battery every POLL_MS milliseconds.
/// Computes a ThrottleLevel and broadcasts it over the kasugai socket
/// so the Python daemon and QML HUD can react instantly.
///
/// ThrottleLevel:
///   0 = NOMINAL   — full speed, no restrictions
///   1 = WARM      — reduce shader complexity, keep AI at full speed
///   2 = HOT       — throttle AI generation speed (lower num_predict)
///   3 = CRITICAL  — emergency: pause AI generation, drop shader to minimum

use crate::{thermal, load, battery};
use serde::Serialize;
use std::time::Duration;
use tokio::time::sleep;
use log::{info, warn};

pub const POLL_MS: u64 = 3000;

// Thresholds
const TEMP_WARM_C:     f32 = 70.0;
const TEMP_HOT_C:      f32 = 85.0;
const TEMP_CRITICAL_C: f32 = 95.0;
const CPU_WARM_PCT:    f32 = 70.0;
const CPU_HOT_PCT:     f32 = 88.0;
const BAT_LOW_PCT:     u8  = 15;

#[derive(Debug, Clone, Copy, PartialEq, Serialize)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum ThrottleLevel {
    Nominal  = 0,
    Warm     = 1,
    Hot      = 2,
    Critical = 3,
}

#[derive(Debug, Clone, Serialize)]
pub struct GovernorState {
    pub level:       ThrottleLevel,
    pub temp_c:      f32,
    pub cpu_pct:     f32,
    pub load_1m:     f32,
    pub battery_pct: u8,
    pub charging:    bool,
    pub reason:      String,
    /// Suggested ollama num_predict cap (0 = unlimited)
    pub num_predict: u32,
    /// Suggested QML shader quality 0.0–1.0
    pub shader_quality: f32,
}

impl GovernorState {
    pub fn nominal() -> Self {
        Self {
            level: ThrottleLevel::Nominal,
            temp_c: 0.0, cpu_pct: 0.0, load_1m: 0.0,
            battery_pct: 100, charging: true,
            reason: "nominal".into(),
            num_predict: 0,
            shader_quality: 1.0,
        }
    }
}

pub fn compute(temp_c: f32, cpu_pct: f32, load_1m: f32, bat: &battery::BatteryState) -> GovernorState {
    let mut level  = ThrottleLevel::Nominal;
    let mut reason = String::from("nominal");
    let mut num_predict   = 0u32;
    let mut shader_quality = 1.0f32;

    // Temperature gates
    if temp_c >= TEMP_CRITICAL_C {
        level  = ThrottleLevel::Critical;
        reason = format!("temp critical: {:.1}°C", temp_c);
        num_predict    = 32;
        shader_quality = 0.2;
    } else if temp_c >= TEMP_HOT_C {
        level  = ThrottleLevel::Hot;
        reason = format!("temp hot: {:.1}°C", temp_c);
        num_predict    = 128;
        shader_quality = 0.5;
    } else if temp_c >= TEMP_WARM_C {
        level  = ThrottleLevel::Warm;
        reason = format!("temp warm: {:.1}°C", temp_c);
        shader_quality = 0.75;
    }

    // CPU load gates (only escalate, never de-escalate from temp)
    if cpu_pct >= CPU_HOT_PCT && (level as u8) < ThrottleLevel::Hot as u8 {
        level  = ThrottleLevel::Hot;
        reason = format!("cpu hot: {:.1}%", cpu_pct);
        num_predict    = 128;
        shader_quality = 0.5;
    } else if cpu_pct >= CPU_WARM_PCT && (level as u8) < ThrottleLevel::Warm as u8 {
        level  = ThrottleLevel::Warm;
        reason = format!("cpu warm: {:.1}%", cpu_pct);
        shader_quality = 0.75;
    }

    // Battery gate — low + discharging → warm throttle minimum
    if bat.present && !bat.charging && bat.percent <= BAT_LOW_PCT
        && (level as u8) < ThrottleLevel::Warm as u8
    {
        level  = ThrottleLevel::Warm;
        reason = format!("battery low: {}%", bat.percent);
        shader_quality = 0.75;
    }

    GovernorState {
        level,
        temp_c,
        cpu_pct,
        load_1m,
        battery_pct: bat.percent,
        charging: bat.charging,
        reason,
        num_predict,
        shader_quality,
    }
}

/// Polling loop — yields GovernorState on each tick.
pub async fn poll_loop(mut on_state: impl FnMut(GovernorState)) {
    let mut prev_jiffies = load::read_cpu_jiffies();
    let mut last_level   = ThrottleLevel::Nominal;

    loop {
        sleep(Duration::from_millis(POLL_MS)).await;

        let temp_c   = thermal::read_max_temp_c();
        let curr_j   = load::read_cpu_jiffies();
        let cpu_pct  = load::cpu_pct(prev_jiffies, curr_j);
        prev_jiffies = curr_j;
        let (l1, _, _) = load::read_loadavg();
        let bat      = battery::read_battery();

        let state = compute(temp_c, cpu_pct, l1, &bat);

        if state.level != last_level {
            match state.level {
                ThrottleLevel::Nominal  => info!("[governor] NOMINAL — {}", state.reason),
                ThrottleLevel::Warm     => warn!("[governor] WARM — {}", state.reason),
                ThrottleLevel::Hot      => warn!("[governor] HOT — {}", state.reason),
                ThrottleLevel::Critical => warn!("[governor] CRITICAL — {}", state.reason),
            }
            last_level = state.level;
        }

        on_state(state);
    }
}
