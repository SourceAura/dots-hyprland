/// shigurui-ebpf — Kernel-level egress telemetry via eBPF
///
/// Runs in two modes:
///   Full mode:  TC egress hook attached (requires egress.bpf.o + CAP_NET_ADMIN)
///   Stub mode:  IPC socket only — responds to CIRCUIT_VERIFY queries,
///               reports healthy=true. Used when eBPF .o is not compiled.
///
/// Build with kernel hook:
///   clang -O2 -target bpf -c src/ebpf/egress.bpf.c -o src/ebpf/egress.bpf.o
///   cargo build --release --features ebpf_obj

mod probe;
mod events;
mod ipc;

use anyhow::Result;
use log::info;

#[tokio::main]
async fn main() -> Result<()> {
    env_logger::init();
    info!("[ebpf] ASE eBPF Telemetry Bridge starting");

    let iface = probe::detect_default_iface()?;
    info!("[ebpf] Default interface: {}", iface);

    let bpf_opt = probe::load_and_attach(&iface).await?;

    match bpf_opt {
        Some(mut bpf) => {
            info!("[ebpf] Full mode — TC egress hook active");
            ipc::run(Some(&mut bpf), &iface).await
        }
        None => {
            info!("[ebpf] Stub mode — IPC socket only (no kernel hook)");
            ipc::run(None, &iface).await
        }
    }
}
