/// ipc.rs — Governor IPC: broadcasts GovernorState to kasugai socket
/// and exposes a Unix socket at /tmp/shigurui-governor.sock for direct reads.
///
/// Broadcast format (JSON, newline-delimited):
///   { "type": "GOVERNOR_STATE", "level": "NOMINAL"|"WARM"|"HOT"|"CRITICAL",
///     "temp_c": 62.5, "cpu_pct": 45.2, "load_1m": 1.2,
///     "battery_pct": 87, "charging": true, "reason": "nominal",
///     "num_predict": 0, "shader_quality": 1.0 }

use crate::governor::{self, GovernorState};
use anyhow::Result;
use log::{info, warn};
use std::path::Path;
use std::sync::{Arc, Mutex};
use tokio::io::AsyncWriteExt;
use tokio::net::{UnixListener, UnixStream};

const GOVERNOR_SOCK: &str = "/tmp/sim-governor.sock";
const KASUGAI_SOCK:  &str = "/tmp/sim-kasugai-events.sock";

pub async fn run() -> Result<()> {
    // Clean up stale socket
    if Path::new(GOVERNOR_SOCK).exists() {
        std::fs::remove_file(GOVERNOR_SOCK)?;
    }

    let listener = UnixListener::bind(GOVERNOR_SOCK)?;
    info!("[governor] Listening on {}", GOVERNOR_SOCK);

    // Shared latest state for direct-read clients
    let latest: Arc<Mutex<Option<GovernorState>>> = Arc::new(Mutex::new(None));
    let latest_poll = latest.clone();

    // Spawn the polling loop
    tokio::spawn(async move {
        governor::poll_loop(move |state| {
            // Update shared state
            if let Ok(mut guard) = latest_poll.lock() {
                *guard = Some(state.clone());
            }
            // Fire-and-forget broadcast to kasugai events socket
            let state_clone = state.clone();
            tokio::spawn(async move {
                let _ = broadcast_to_kasugai(&state_clone).await;
            });
        }).await;
    });

    // Accept direct-read connections
    loop {
        let (stream, _) = listener.accept().await?;
        let latest_conn = latest.clone();
        tokio::spawn(async move {
            handle_client(stream, latest_conn).await;
        });
    }
}

async fn handle_client(mut stream: UnixStream, latest: Arc<Mutex<Option<GovernorState>>>) {
    let state = latest.lock().ok().and_then(|g| g.clone());
    let json = match state {
        Some(s) => serde_json::to_string(&GovernorPayload::from(s)).unwrap_or_default(),
        None    => r#"{"type":"GOVERNOR_STATE","level":"NOMINAL"}"#.to_string(),
    };
    let _ = stream.write_all(format!("{}\n", json).as_bytes()).await;
}

async fn broadcast_to_kasugai(state: &GovernorState) -> Result<()> {
    if !Path::new(KASUGAI_SOCK).exists() { return Ok(()); }
    let mut stream = UnixStream::connect(KASUGAI_SOCK).await?;
    let payload = GovernorPayload::from(state.clone());
    let json = serde_json::to_string(&payload)?;
    stream.write_all(format!("{}\n", json).as_bytes()).await?;
    Ok(())
}

#[derive(serde::Serialize)]
struct GovernorPayload {
    #[serde(rename = "type")]
    event_type:    String,
    level:         String,
    temp_c:        f32,
    cpu_pct:       f32,
    load_1m:       f32,
    battery_pct:   u8,
    charging:      bool,
    reason:        String,
    num_predict:   u32,
    shader_quality: f32,
}

impl From<GovernorState> for GovernorPayload {
    fn from(s: GovernorState) -> Self {
        Self {
            event_type:    "GOVERNOR_STATE".into(),
            level:         format!("{:?}", s.level).to_uppercase(),
            temp_c:        s.temp_c,
            cpu_pct:       s.cpu_pct,
            load_1m:       s.load_1m,
            battery_pct:   s.battery_pct,
            charging:      s.charging,
            reason:        s.reason,
            num_predict:   s.num_predict,
            shader_quality: s.shader_quality,
        }
    }
}
