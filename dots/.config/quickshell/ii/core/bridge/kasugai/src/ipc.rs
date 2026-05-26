/* ipc.rs — The Syndicate IPC Interface
 * =====================================
 * Handles incoming JSON queries from the FastAPI socket client,
 * maps breathing style state, runs policy checks against the manifest,
 * and streams stdout/stderr outputs over the Unix socket in real-time.
 *
 * Fold: SAGE (◈) — Command Routing & Real-Time Communication.
 */

use serde_json::{json, Value};
use std::sync::{RwLock, OnceLock};
use std::process::Stdio;
use tokio::io::{AsyncBufReadExt, AsyncWriteExt, BufReader as TokioBufReader};
use tokio::process::Command as TokioCommand;
use log::{info, warn, error};
use anyhow::Context;

use crate::substrate::{SubstrateManager, CommandIntent};

// Central static states
pub static CURRENT_STYLE: RwLock<&'static str> = RwLock::new("moon");
pub static SUBSTRATE_MANAGER: OnceLock<SubstrateManager> = OnceLock::new();

/// Dispatch an incoming command string.
/// If streaming process outputs, returns a single initialization response.
/// The caller handle_connection will continue execution if needed.
pub async fn dispatch(cmd: &str) -> String {
    let result: Value = match cmd {
        "ping" => json!({ "ok": true, "msg": "pong" }),
        "status" => handle_status().await,
        _ if cmd.starts_with('{') => {
            match serde_json::from_str::<Value>(cmd) {
                Ok(msg) => handle_json_message(msg).await,
                Err(e) => json!({ "ok": false, "error": format!("json parse error: {e}") }),
            }
        }
        _ => json!({ "ok": false, "error": format!("unknown command: {cmd}") }),
    };
    result.to_string()
}

async fn handle_status() -> Value {
    let style = match CURRENT_STYLE.read() {
        Ok(guard) => *guard,
        Err(_) => "moon",
    };
    json!({
        "ok": true,
        "daemon": "kasugai",
        "version": env!("CARGO_PKG_VERSION"),
        "status": "running",
        "style": style
    })
}

async fn handle_json_message(msg: Value) -> Value {
    let msg_type = msg["type"].as_str().unwrap_or("unknown");
    let payload = msg["payload"].as_str().unwrap_or("").to_string();

    match msg_type {
        "SET_STYLE" => {
            let style_str = payload.to_lowercase();
            let mut style_guard = CURRENT_STYLE.write().unwrap();
            
            // Map styles to static references
            if style_str == "sun" {
                *style_guard = "sun";
            } else if style_str == "moon" {
                *style_guard = "moon";
            } else {
                *style_guard = "celestial"; // Prismatic
            }
            
            info!("[kasugai] Active Sovereign Breathing Style set to: {}", *style_guard);
            json!({ "ok": true, "style": *style_guard })
        }
        "EXECUTE_COMMAND" => {
            let style = match CURRENT_STYLE.read() {
                Ok(guard) => *guard,
                Err(_) => "moon",
            };
            let intent = CommandIntent {
                command: payload.clone(),
                style: style.to_string(),
            };

            let manager = SUBSTRATE_MANAGER.get().expect("SubstrateManager not initialized");
            let auth = manager.authorize_intent(&intent).await;

            if !auth.authorized {
                return json!({
                    "type": "AUTH_DECISION",
                    "authorized": false,
                    "reason": auth.reason,
                    "thoughts": auth.thoughts,
                    "command": payload
                });
            }

            json!({
                "type": "AUTH_DECISION",
                "authorized": true,
                "reason": "Authorized by 7 Sibyls.",
                "thoughts": auth.thoughts,
                "command": auth.rewritten_command
            })
        }
        _ => {
            json!({ "ok": false, "error": format!("unknown type: {msg_type}") })
        }
    }
}

/// Execute command and stream stdout/stderr lines down the socket connection writer.
pub async fn execute_and_stream(
    command_str: &str,
    writer: std::sync::Arc<tokio::sync::Mutex<tokio::net::unix::OwnedWriteHalf>>
) -> Result<(), anyhow::Error> {
    info!("[kasugai] Substrate: Spawning sandboxed command: {command_str}");
    
    let parts: Vec<&str> = command_str.split_whitespace().collect();
    if parts.is_empty() {
        return Ok(());
    }

    let program = parts[0];
    let args = &parts[1..];

    let mut child = TokioCommand::new(program)
        .args(args)
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()
        .context(format!("Failed to spawn program: {program}"))?;

    let stdout = child.stdout.take().context("Failed to open stdout pipe")?;
    let stderr = child.stderr.take().context("Failed to open stderr pipe")?;

    let writer_stdout = writer.clone();
    let stdout_handle = tokio::spawn(async move {
        let mut reader = TokioBufReader::new(stdout).lines();
        while let Ok(Some(line)) = reader.next_line().await {
            let msg = json!({ "type": "STDOUT", "data": line }).to_string();
            let mut w = writer_stdout.lock().await;
            let _ = w.write_all(format!("{msg}\n").as_bytes()).await;
        }
    });

    let writer_stderr = writer.clone();
    let stderr_handle = tokio::spawn(async move {
        let mut reader = TokioBufReader::new(stderr).lines();
        while let Ok(Some(line)) = reader.next_line().await {
            let msg = json!({ "type": "STDERR", "data": line }).to_string();
            let mut w = writer_stderr.lock().await;
            let _ = w.write_all(format!("{msg}\n").as_bytes()).await;
        }
    });

    // Wait for outputs to finish
    let _ = tokio::join!(stdout_handle, stderr_handle);

    // Wait for child to exit
    let status = child.wait().await?;
    let code = status.code().unwrap_or(0);
    
    let exit_msg = json!({ "type": "EXIT", "code": code }).to_string();
    let mut w = writer.lock().await;
    let _ = w.write_all(format!("{exit_msg}\n").as_bytes()).await;
    
    info!("[kasugai] Substrate: Command execution complete with status code: {code}");
    Ok(())
}
