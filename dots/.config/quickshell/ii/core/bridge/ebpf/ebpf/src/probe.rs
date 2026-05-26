/// probe.rs — eBPF program loading and TC hook attachment
use anyhow::{Context, Result};
use aya::{
    Bpf,
    programs::{tc, SchedClassifier, TcAttachType},
};
use log::info;
use std::fs;

// The compiled eBPF object is embedded at build time.
// Build with: clang -O2 -target bpf -c src/ebpf/egress.bpf.c -o src/ebpf/egress.bpf.o
// If the .o is absent the daemon runs in stub mode (IPC only, no kernel hook).
#[cfg(feature = "ebpf_obj")]
static EGRESS_BPF_OBJ: &[u8] = include_bytes!("ebpf/egress.bpf.o");

/// Detect the default egress network interface by reading /proc/net/route.
pub fn detect_default_iface() -> Result<String> {
    let route = fs::read_to_string("/proc/net/route")
        .context("Failed to read /proc/net/route")?;

    for line in route.lines().skip(1) {
        let cols: Vec<&str> = line.split_whitespace().collect();
        if cols.len() < 2 { continue; }
        if cols[1] == "00000000" {
            return Ok(cols[0].to_string());
        }
    }

    for line in route.lines().skip(1) {
        let cols: Vec<&str> = line.split_whitespace().collect();
        if let Some(iface) = cols.first() {
            if *iface != "lo" {
                return Ok(iface.to_string());
            }
        }
    }

    anyhow::bail!("No default network interface found")
}

/// Load the eBPF object and attach it to the TC egress hook.
/// Returns None if the .o object is not compiled in (stub mode).
pub async fn load_and_attach(iface: &str) -> Result<Option<Bpf>> {
    #[cfg(feature = "ebpf_obj")]
    {
        let mut bpf = Bpf::load(EGRESS_BPF_OBJ)
            .context("Failed to load eBPF object")?;

        tc::qdisc_add_clsact(iface)
            .map_err(|e| anyhow::anyhow!("Failed to add clsact qdisc: {}", e))?;

        let program: &mut SchedClassifier = bpf
            .program_mut("shigurui_egress")
            .context("eBPF program 'shigurui_egress' not found in object")?
            .try_into()?;

        program.load()?;
        program
            .attach(iface, TcAttachType::Egress)
            .map_err(|e| anyhow::anyhow!("Failed to attach TC egress: {}", e))?;

        info!("[ebpf] shigurui_egress attached to {} egress", iface);
        return Ok(Some(bpf));
    }

    #[cfg(not(feature = "ebpf_obj"))]
    {
        log::warn!("[ebpf] No eBPF object compiled in — running in stub/IPC-only mode");
        log::warn!("[ebpf] To enable kernel hooks: clang -O2 -target bpf -c src/ebpf/egress.bpf.c -o src/ebpf/egress.bpf.o");
        Ok(None)
    }
}
