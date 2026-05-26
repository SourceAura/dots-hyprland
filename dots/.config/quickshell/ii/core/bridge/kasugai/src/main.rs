/* main.rs — Shigurui Kasugai Headless Socket Daemon
 * ===================================================
 * Entry point for the Kasugai privilege gatekeeper.
 * Spawns Unix domain listener, maintains thread-safe connection states,
 * and coordinates substrate process streaming.
 *
 * Fold: SAGE (◈) — Central Orchestration Daemon.
 */

mod ipc;
mod db;
mod substrate;

use anyhow::Result;
use log::info;
use tokio::net::UnixListener;
use tokio::io::{AsyncBufReadExt, AsyncWriteExt, BufReader};
use std::path::Path;
use std::sync::Arc;
use tokio::sync::Mutex;

const SOCKET_PATH: &str = "/tmp/sim-kasugai.sock";

#[tokio::main]
async fn main() -> Result<()> {
    env_logger::init();
    info!("[kasugai] Headless daemon starting");

    db::init().await?;

    // Dynamic Initialization of the Syndicate SubstrateManager
    ipc::SUBSTRATE_MANAGER.set(substrate::SubstrateManager::new()).ok();

    // Clean up stale socket
    if Path::new(SOCKET_PATH).exists() {
        std::fs::remove_file(SOCKET_PATH)?;
    }

    let listener = UnixListener::bind(SOCKET_PATH)?;
    info!("[kasugai] Listening on {}", SOCKET_PATH);

    loop {
        let (stream, _) = listener.accept().await?;
        tokio::spawn(async move {
            if let Err(e) = handle_connection(stream).await {
                log::error!("[kasugai] connection error: {e}");
            }
        });
    }
}

async fn handle_connection(stream: tokio::net::UnixStream) -> Result<()> {
    let (reader, writer) = stream.into_split();
    let writer_shared = Arc::new(Mutex::new(writer));
    let mut lines = BufReader::new(reader).lines();

    while let Some(line) = lines.next_line().await? {
        let line = line.trim().to_string();
        if line.is_empty() { continue; }

        info!("[kasugai] cmd: {line}");
        let response_str = ipc::dispatch(&line).await;
        
        // Write the authorization decision back to python/QML first
        {
            let mut w = writer_shared.lock().await;
            w.write_all(format!("{response_str}\n").as_bytes()).await?;
        }
        
        // If it was an EXECUTE_COMMAND that got authorized by all 7 Sibyls, run and stream output
        if let Ok(resp_val) = serde_json::from_str::<serde_json::Value>(&response_str) {
            if resp_val["type"] == "AUTH_DECISION" && resp_val["authorized"] == true {
                if let Some(rewritten_cmd) = resp_val["command"].as_str() {
                    let writer_clone = writer_shared.clone();
                    if let Err(e) = ipc::execute_and_stream(rewritten_cmd, writer_clone).await {
                        log::error!("[kasugai] Substrate: Execution streaming failed: {:?}", e);
                    }
                }
            }
        }
    }
    Ok(())
}
