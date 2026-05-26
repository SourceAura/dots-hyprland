use anyhow::Result;
use rusqlite::Connection;
use std::path::PathBuf;

fn db_path() -> PathBuf {
    dirs_next::data_dir()
        .unwrap_or_else(|| PathBuf::from("/tmp"))
        .join("shigurui")
        .join("kasugai.db")
}

pub async fn init() -> Result<()> {
    let path = db_path();
    if let Some(parent) = path.parent() {
        std::fs::create_dir_all(parent)?;
    }
    let conn = Connection::open(&path)?;
    conn.execute_batch(
        "CREATE TABLE IF NOT EXISTS events (
            id        INTEGER PRIMARY KEY AUTOINCREMENT,
            ts        TEXT    NOT NULL DEFAULT (datetime('now')),
            kind      TEXT    NOT NULL,
            payload   TEXT
        );",
    )?;
    log::info!("[kasugai] db ready at {}", path.display());
    Ok(())
}

pub fn log_event(kind: &str, payload: &str) -> Result<()> {
    let conn = Connection::open(db_path())?;
    conn.execute(
        "INSERT INTO events (kind, payload) VALUES (?1, ?2)",
        rusqlite::params![kind, payload],
    )?;
    Ok(())
}
