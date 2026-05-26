/// battery.rs — Read battery state from /sys/class/power_supply
use std::fs;

#[derive(Debug, Clone)]
pub struct BatteryState {
    pub present:    bool,
    pub charging:   bool,
    pub percent:    u8,
    pub status:     String,   // "Charging" | "Discharging" | "Full" | "Unknown"
}

impl Default for BatteryState {
    fn default() -> Self {
        Self { present: false, charging: false, percent: 100, status: "Unknown".into() }
    }
}

pub fn read_battery() -> BatteryState {
    let Ok(entries) = fs::read_dir("/sys/class/power_supply") else {
        return BatteryState::default();
    };
    for entry in entries.flatten() {
        let path = entry.path();
        let name = path.file_name().unwrap_or_default().to_string_lossy().to_string();
        // Look for BAT* entries
        if !name.starts_with("BAT") { continue; }

        let read = |f: &str| fs::read_to_string(path.join(f))
            .unwrap_or_default()
            .trim()
            .to_string();

        let status  = read("status");
        let cap_str = read("capacity");
        let percent = cap_str.parse::<u8>().unwrap_or(100);
        let charging = status == "Charging" || status == "Full";

        return BatteryState {
            present: true,
            charging,
            percent,
            status,
        };
    }
    BatteryState::default()
}
