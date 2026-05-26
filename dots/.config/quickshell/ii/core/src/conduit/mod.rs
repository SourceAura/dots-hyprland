// core/src/conduit/mod.rs
// Sun iN Moon (SiM) — Conduit Terminal PTY Daemon Interface

use std::sync::Arc;
use tokio::sync::Mutex;
use portable_pty::{CommandBuilder, NativePtySystem, PtySize, PtySystem};
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use futures_util::{StreamExt, SinkExt};
use warp::ws::{Message, WebSocket};

pub struct ConduitSession {
    pub pty_write: Arc<Mutex<Box<dyn std::io::Write + Send>>>,
}

impl ConduitSession {
    pub async fn spawn(
        cols: u16,
        rows: u16,
        ws_sender: Arc<Mutex<futures_util::stream::SplitSink<WebSocket, Message>>>
    ) -> Result<Self, Box<dyn std::error::Error>> {
        let pty_system = NativePtySystem::default();
        let pair = pty_system.openpty(PtySize {
            rows,
            cols,
            pixel_width: 0,
            pixel_height: 0,
        })?;

        let cmd = CommandBuilder::new("bash");
        let _child = pair.slave.spawn_command(cmd)?;

        let reader = pair.master.try_clone_reader()?;
        let writer = pair.master.take_writer()?;
        
        let pty_write = Arc::new(Mutex::new(writer));

        // Read channel async wrapper
        tokio::task::spawn_blocking(move || {
            tokio::runtime::Handle::current().block_on(async {
                let mut reader = reader;
                let mut buffer = [0u8; 4096];
                loop {
                    match reader.read(&mut buffer) {
                        Ok(n) if n > 0 => {
                            let text = String::from_utf8_lossy(&buffer[..n]).to_string();
                            
                            // 1. Inline Lexical parsing for IOCs
                            let processed_output = parse_indicators(&text);

                            // 2. Stream to browser
                            let mut ws = ws_sender.lock().await;
                            let _ = ws.send(Message::text(processed_output)).await;
                        }
                        _ => break,
                    }
                }
            })
        });

        Ok(Self { pty_write })
    }
}

// Intercept streams and inject bright ANSI alerts if critical security events fire
fn parse_indicators(input: &str) -> String {
    let mut output = input.to_string();
    let ioc_patterns = vec![
        ("VULNERABLE", "\x1b[1;31m[!] VULNERABLE\x1b[0m"),
        ("EXPLOIT", "\x1b[1;31m[!] EXPLOIT DETECTED\x1b[0m"),
        ("SUCCESS", "\x1b[1;32m[+] CRITICAL PATH ALIGNED\x1b[0m"),
    ];

    for (pattern, replacement) in ioc_patterns {
        if output.contains(pattern) {
            output = output.replace(pattern, replacement);
        }
    }
    output
}
