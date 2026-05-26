# ASE eBPF Telemetry Bridge

Kernel-level egress packet telemetry using eBPF TC (traffic control) hooks.

## Architecture

1. **eBPF Program** (`src/ebpf/egress.bpf.c`)
   - Attaches to TC egress hook on default network interface
   - Extracts packet metadata: dst IP, dst port, protocol, PID, UID, process name
   - Writes events to perf event array (does NOT block packets)

2. **Userspace Daemon** (`src/main.rs`, `src/ipc.rs`, `src/probe.rs`)
   - Loads and attaches eBPF program
   - Reads perf events from all CPUs
   - Filters out loopback traffic
   - Broadcasts JSON events to:
     - `/tmp/shigurui-kasugai-events.sock` → Python daemon → WebSocket → QML HUD
     - `/tmp/shigurui-ebpf.sock` (direct read socket, last 10 events)

## Build

```bash
# 1. Compile eBPF C program
./compile.sh

# 2. Build Rust daemon
cargo build --release

# 3. Binary output
target/release/shigurui-ebpf
```

## Requirements

- **Kernel:** Linux 5.10+ with BTF support
- **Capabilities:** `CAP_NET_ADMIN` or root
- **Dependencies:**
  - `clang` (for eBPF compilation)
  - `libbpf-dev` or `bpf-headers` package
  - Rust 1.70+

## Run

```bash
# As root (or with CAP_NET_ADMIN)
sudo ./target/release/shigurui-ebpf

# Or via systemd (recommended)
sudo systemctl start shigurui-ebpf
```

## Event Format

```json
{
  "type": "EGRESS_EVENT",
  "pid": 12345,
  "uid": 1000,
  "dst_ip": "1.1.1.1",
  "dst_port": 443,
  "proto": "TCP",
  "comm": "firefox",
  "verdict": "CLEARED",
  "ts": "uptime+1234.56s"
}
```

## Systemd Service

See `shigurui-ebpf.service` for systemd integration with ambient capabilities.

## Troubleshooting

**Error: "Failed to add clsact qdisc"**
- Requires `CAP_NET_ADMIN` capability
- Run with `sudo` or add `AmbientCapabilities=CAP_NET_ADMIN` to systemd unit

**Error: "eBPF program 'ase_egress' not found"**
- Ensure `egress.bpf.o` was compiled successfully
- Check that `SEC("classifier/ase_egress")` matches program name in C source

**No events appearing:**
- Check that default interface is correct: `ip route | grep default`
- Verify eBPF program is attached: `tc filter show dev <iface> egress`
- Check logs: `journalctl -u shigurui-ebpf -f`

## Security Notes

- This daemon sees ALL egress traffic metadata (not packet contents)
- Loopback (127.0.0.0/8) traffic is filtered out
- Events are broadcast to local Unix sockets only (no network exposure)
- eBPF programs are verified by the kernel and cannot crash the system
