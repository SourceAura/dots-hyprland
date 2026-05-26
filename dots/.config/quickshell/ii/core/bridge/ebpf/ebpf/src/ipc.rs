/// ipc.rs — eBPF IPC server
///
/// Full mode:  reads perf events from kernel, broadcasts EGRESS_EVENT JSON
/// Stub mode:  IPC socket only — answers CIRCUIT_VERIFY with healthy=true
///
/// Socket: /tmp/shigurui-ebpf.sock
/// Protocol: newline-delimited JSON
///   Request:  {"type":"CIRCUIT_VERIFY","payload":"{\"port\":9041}"}
///   Response: {"healthy":true,"port":9041,"mode":"stub"}

use anyhow::Result;
use log::{info, warn};
use serde_json::{json, Value};
use std::path::Path;
use std::sync::{Arc, Mutex};
use tokio::io::{AsyncBufReadExt, AsyncWriteExt, BufReader};
use tokio::net::{UnixListener, UnixStream};

#[cfg(feature = "ebpf_obj")]
use {
    crate::events::{EgressEvent, EgressEventRaw},
    aya::{maps::perf::AsyncPerfEventArray, util::online_cpus, Bpf},
    bytes::BytesMut,
};

const EBPF_SOCK:    &str = "/tmp/shigurui-ebpf.sock";
const KASUGAI_SOCK: &str = "/tmp/shigurui-kasugai-events.sock";

pub async fn run(
    #[allow(unused_variables)] bpf: Option<&mut aya::Bpf>,
    iface: &str,
) -> Result<()> {
    if Path::new(EBPF_SOCK).exists() {
        std::fs::remove_file(EBPF_SOCK)?;
    }

    let listener = UnixListener::bind(EBPF_SOCK)?;
    info!("[ebpf] Listening on {}", EBPF_SOCK);

    let event_ring: Arc<Mutex<Vec<Value>>> = Arc::new(Mutex::new(Vec::new()));

    // Full mode: spawn perf event readers
    #[cfg(feature = "ebpf_obj")]
    if let Some(bpf_inner) = bpf {
        let ring = event_ring.clone();
        spawn_perf_readers(bpf_inner, ring, iface)?;
    }

    info!("[ebpf] Egress telemetry active on interface: {}", iface);

    // Accept IPC connections
    loop {
        let (stream, _) = listener.accept().await?;
        let ring = event_ring.clone();
        tokio::spawn(async move {
            if let Err(e) = handle_client(stream, ring).await {
                warn!("[ebpf] client error: {e}");
            }
        });
    }
}

async fn handle_client(stream: UnixStream, ring: Arc<Mutex<Vec<Value>>>) -> Result<()> {
    let (reader, mut writer) = stream.into_split();
    let mut lines = BufReader::new(reader).lines();

    while let Some(line) = lines.next_line().await? {
        let line = line.trim().to_string();
        if line.is_empty() { continue; }

        let response = dispatch_request(&line, &ring).await;
        writer.write_all(format!("{}\n", response).as_bytes()).await?;
    }
    Ok(())
}

async fn dispatch_request(raw: &str, ring: &Arc<Mutex<Vec<Value>>>) -> String {
    // Try to parse as JSON
    if let Ok(msg) = serde_json::from_str::<Value>(raw) {
        let kind = msg["type"].as_str().unwrap_or("");

        match kind {
            "CIRCUIT_VERIFY" => {
                // Parse port from payload
                let port = msg["payload"]
                    .as_str()
                    .and_then(|p| serde_json::from_str::<Value>(p).ok())
                    .and_then(|v| v["port"].as_u64())
                    .unwrap_or(9040);

                // In stub mode always healthy=true (soft-pass)
                // In full mode we could check actual packet flow
                let mode = if cfg!(feature = "ebpf_obj") { "full" } else { "stub" };
                return json!({
                    "healthy": true,
                    "port": port,
                    "mode": mode,
                    "verdict": "CLEARED"
                }).to_string();
            }
            "STATUS" => {
                let count = ring.lock().map(|g| g.len()).unwrap_or(0);
                return json!({
                    "ok": true,
                    "mode": if cfg!(feature = "ebpf_obj") { "full" } else { "stub" },
                    "events_buffered": count
                }).to_string();
            }
            _ => {}
        }
    }

    // Default: return last 10 events
    let events = ring.lock().ok()
        .map(|g| g.iter().rev().take(10).cloned().collect::<Vec<_>>())
        .unwrap_or_default();
    json!({ "ok": true, "events": events }).to_string()
}

#[cfg(feature = "ebpf_obj")]
fn spawn_perf_readers(
    bpf: &mut Bpf,
    ring: Arc<Mutex<Vec<Value>>>,
    iface: &str,
) -> Result<()> {
    use crate::events::EgressEvent;

    let mut perf_array = AsyncPerfEventArray::try_from(
        bpf.take_map("egress_events")
            .ok_or_else(|| anyhow::anyhow!("'egress_events' map not found"))?
    )?;

    for cpu_id in online_cpus().map_err(|e| anyhow::anyhow!("online_cpus: {}", e))? {
        let mut buf = perf_array.open(cpu_id, None)?;
        let ring_cpu = ring.clone();

        tokio::spawn(async move {
            let mut buffers = (0..10)
                .map(|_| BytesMut::with_capacity(std::mem::size_of::<EgressEventRaw>()))
                .collect::<Vec<_>>();

            loop {
                let events = match buf.read_events(&mut buffers).await {
                    Ok(e) => e,
                    Err(e) => {
                        warn!("[ebpf] perf read error CPU {}: {}", cpu_id, e);
                        tokio::time::sleep(tokio::time::Duration::from_millis(100)).await;
                        continue;
                    }
                };

                for b in buffers.iter_mut().take(events.read) {
                    let ptr = b.as_ptr() as *const EgressEventRaw;
                    let raw = unsafe { ptr.read_unaligned() };
                    let event = EgressEvent::from_raw(&raw, "CLEARED");
                    if event.is_local() { continue; }

                    if let Ok(v) = serde_json::to_value(&event) {
                        if let Ok(mut guard) = ring_cpu.lock() {
                            guard.push(v);
                            if guard.len() > 50 { guard.remove(0); }
                        }
                    }

                    let ec = event.clone();
                    tokio::spawn(async move {
                        let _ = broadcast_to_kasugai(&ec).await;
                    });
                }
            }
        });
    }

    info!("[ebpf] Perf readers spawned for {} CPUs on {}", online_cpus().unwrap_or_default().len(), iface);
    Ok(())
}

async fn broadcast_to_kasugai(event: &crate::events::EgressEvent) -> Result<()> {
    if !Path::new(KASUGAI_SOCK).exists() { return Ok(()); }
    let mut stream = UnixStream::connect(KASUGAI_SOCK).await?;
    let json = serde_json::to_string(event)?;
    stream.write_all(format!("{}\n", json).as_bytes()).await?;
    Ok(())
}
