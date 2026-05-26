/// events.rs — Packet event types shared between kernel and userspace
///
/// The eBPF program writes EgressEvent structs into a perf event array.
/// This module defines the userspace mirror of that struct.

use serde::Serialize;

/// Mirror of the C struct egress_event_t in egress.bpf.c
/// Must match field layout exactly (repr C, no padding surprises).
#[repr(C)]
#[derive(Debug, Clone, Copy)]
pub struct EgressEventRaw {
    pub pid:      u32,
    pub uid:      u32,
    pub dst_ip:   u32,   // network byte order (big-endian)
    pub dst_port: u16,   // network byte order
    pub proto:    u8,    // IPPROTO_TCP=6, IPPROTO_UDP=17
    pub _pad:     u8,
    pub comm:     [u8; 16],  // process name, null-terminated
}

/// Parsed, human-readable egress event for JSON broadcast.
#[derive(Debug, Clone, Serialize)]
pub struct EgressEvent {
    #[serde(rename = "type")]
    pub event_type: String,
    pub pid:        u32,
    pub uid:        u32,
    pub dst_ip:     String,
    pub dst_port:   u16,
    pub proto:      String,
    pub comm:       String,
    pub verdict:    String,   // "CLEARED" | "BLOCKED" (set by userspace policy)
    pub ts:         String,
}

impl EgressEvent {
    pub fn from_raw(raw: &EgressEventRaw, verdict: &str) -> Self {
        let ip = raw.dst_ip.to_be();
        let dst_ip = format!(
            "{}.{}.{}.{}",
            (ip >> 24) & 0xFF,
            (ip >> 16) & 0xFF,
            (ip >>  8) & 0xFF,
             ip        & 0xFF,
        );
        let dst_port = u16::from_be(raw.dst_port);
        let proto = match raw.proto {
            6  => "TCP",
            17 => "UDP",
            1  => "ICMP",
            _  => "OTHER",
        }.to_string();
        let comm = raw.comm.iter()
            .take_while(|&&b| b != 0)
            .map(|&b| b as char)
            .collect();
        let ts = chrono_ts();
        Self {
            event_type: "EGRESS_EVENT".into(),
            pid: raw.pid,
            uid: raw.uid,
            dst_ip,
            dst_port,
            proto,
            comm,
            verdict: verdict.to_string(),
            ts,
        }
    }

    /// Returns true if this is a loopback/local packet we should skip.
    pub fn is_local(&self) -> bool {
        self.dst_ip.starts_with("127.")
            || self.dst_ip.starts_with("::1")
            || self.dst_ip == "0.0.0.0"
    }
}

fn chrono_ts() -> String {
    use std::time::{SystemTime, UNIX_EPOCH};
    match SystemTime::now().duration_since(UNIX_EPOCH) {
        Ok(d) => format!("{}.{:03}", d.as_secs(), d.subsec_millis()),
        Err(_) => "unknown".into(),
    }
}
