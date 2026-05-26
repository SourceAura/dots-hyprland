mod thermal;
mod load;
mod battery;
mod governor;
mod ipc;

use anyhow::Result;
use log::info;

#[tokio::main]
async fn main() -> Result<()> {
    env_logger::init();
    info!("[governor] Equivalent Exchange Governor starting");
    ipc::run().await
}
