/// thermal.rs — Read CPU thermal zones from /sys/class/thermal
use std::fs;
use anyhow::Result;

/// Returns the highest CPU temperature in millidegrees Celsius.
/// Returns 0 if no thermal zones are readable.
pub fn read_max_temp_mc() -> u64 {
    let Ok(entries) = fs::read_dir("/sys/class/thermal") else { return 0 };
    let mut max = 0u64;
    for entry in entries.flatten() {
        let path = entry.path();
        let name = path.file_name().unwrap_or_default().to_string_lossy().to_string();
        if !name.starts_with("thermal_zone") { continue }
        let type_path = path.join("type");
        let temp_path = path.join("temp");
        // Only consider CPU-related zones
        let zone_type = fs::read_to_string(&type_path).unwrap_or_default();
        if !zone_type.contains("cpu") && !zone_type.contains("x86") && !zone_type.contains("acpi") {
            continue;
        }
        if let Ok(raw) = fs::read_to_string(&temp_path) {
            if let Ok(t) = raw.trim().parse::<u64>() {
                if t > max { max = t; }
            }
        }
    }
    max
}

/// Returns temperature in degrees Celsius (f32).
pub fn read_max_temp_c() -> f32 {
    read_max_temp_mc() as f32 / 1000.0
}
