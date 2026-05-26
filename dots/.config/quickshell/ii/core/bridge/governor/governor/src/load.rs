/// load.rs — Read CPU load average and usage from /proc
use std::fs;
use anyhow::Result;

#[derive(Debug, Clone)]
pub struct LoadSnapshot {
    pub load_1m:  f32,
    pub load_5m:  f32,
    pub load_15m: f32,
    pub cpu_pct:  f32,   // instantaneous CPU % (delta between two reads)
}

/// Read /proc/loadavg — returns (1m, 5m, 15m) load averages.
pub fn read_loadavg() -> (f32, f32, f32) {
    let raw = fs::read_to_string("/proc/loadavg").unwrap_or_default();
    let parts: Vec<&str> = raw.split_whitespace().collect();
    let l1  = parts.first().and_then(|s| s.parse().ok()).unwrap_or(0.0);
    let l5  = parts.get(1).and_then(|s| s.parse().ok()).unwrap_or(0.0);
    let l15 = parts.get(2).and_then(|s| s.parse().ok()).unwrap_or(0.0);
    (l1, l5, l15)
}

/// Read /proc/stat first line — returns (total, idle) jiffies.
pub fn read_cpu_jiffies() -> (u64, u64) {
    let raw = fs::read_to_string("/proc/stat").unwrap_or_default();
    let line = raw.lines().next().unwrap_or("");
    let nums: Vec<u64> = line.split_whitespace()
        .skip(1)
        .filter_map(|s| s.parse().ok())
        .collect();
    if nums.len() < 4 { return (0, 0); }
    let idle  = nums[3] + nums.get(4).copied().unwrap_or(0);
    let total: u64 = nums.iter().sum();
    (total, idle)
}

/// Compute CPU % between two jiffie snapshots.
pub fn cpu_pct(prev: (u64, u64), curr: (u64, u64)) -> f32 {
    let dt = curr.0.saturating_sub(prev.0) as f32;
    let di = curr.1.saturating_sub(prev.1) as f32;
    if dt == 0.0 { return 0.0; }
    ((dt - di) / dt * 100.0).clamp(0.0, 100.0)
}
