# eBPF Integration Guide

## Overview

The eBPF telemetry bridge provides real-time egress packet monitoring for the ASE system. Events flow from kernel → userspace → kasugai → WebSocket → QML HUD.

## Data Flow

```
┌─────────────────────────────────────────────────────────────┐
│ Kernel Space                                                 │
│  ┌──────────────────────────────────────────────────────┐   │
│  │ TC Egress Hook (egress.bpf.c)                        │   │
│  │  - Extracts: pid, uid, dst_ip, dst_port, proto, comm│   │
│  │  - Writes to perf event array                        │   │
│  └──────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ Userspace (shigurui-ebpf daemon)                                  │
│  ┌──────────────────────────────────────────────────────┐   │
│  │ Perf Event Reader (ipc.rs)                           │   │
│  │  - Reads from all CPUs                               │   │
│  │  - Filters loopback traffic                          │   │
│  │  - Parses EgressEventRaw → EgressEvent               │   │
│  └──────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
                            ↓
                    ┌───────┴────────┐
                    │                │
                    ↓                ↓
    ┌───────────────────────┐  ┌─────────────────────┐
    │ /tmp/shigurui-ebpf.sock    │  │ /tmp/shigurui-kasugai-   │
    │ (direct read)         │  │ events.sock         │
    │ - Last 10 events      │  │ (broadcast stream)  │
    └───────────────────────┘  └─────────────────────┘
                                        ↓
                            ┌───────────────────────┐
                            │ Kasugai Socket Server │
                            │ (kasugai_socket.py)   │
                            └───────────────────────┘
                                        ↓
                            ┌───────────────────────┐
                            │ Intelligence Feed WS  │
                            │ (ws://127.0.0.1:8001) │
                            └───────────────────────┘
                                        ↓
                            ┌───────────────────────┐
                            │ QML HUD Components    │
                            │ - ArOverlay           │
                            │ - ReconStreamer       │
                            │ - NakimeBiwaLayout    │
                            └───────────────────────┘
```

## Event Schema

### EgressEvent (JSON)

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
  "ts": "1234567890.123"
}
```

### Fields

- `type`: Always "EGRESS_EVENT"
- `pid`: Process ID that sent the packet
- `uid`: User ID of the process
- `dst_ip`: Destination IPv4 address (dotted decimal)
- `dst_port`: Destination port number
- `proto`: Protocol ("TCP", "UDP", "ICMP", "OTHER")
- `comm`: Process name (up to 15 chars)
- `verdict`: "CLEARED" (future: "BLOCKED" for policy enforcement)
- `ts`: Unix timestamp with milliseconds

## QML Integration

### Listening for Events

```qml
WebSocket {
    id: intelligenceFeed
    url: "ws://127.0.0.1:8001/intelligence-feed"
    active: true

    onTextMessageReceived: function(msg) {
        try {
            var event = JSON.parse(msg)
            if (event.type === "EGRESS_EVENT") {
                console.log("Egress:", event.comm, "→", event.dst_ip + ":" + event.dst_port)
                // Update UI state
                handleEgressEvent(event)
            }
        } catch(e) {}
    }
}
```

### Example: Traffic Visualization

```qml
// NakimeBiwaLayout.qml — IP rotation graph
property var recentConnections: []

function handleEgressEvent(event) {
    if (event.proto === "TCP" && event.dst_port === 443) {
        // HTTPS connection detected
        var conn = {
            ip: event.dst_ip,
            port: event.dst_port,
            comm: event.comm,
            ts: Date.now()
        }
        recentConnections.unshift(conn)
        if (recentConnections.length > 20) {
            recentConnections.pop()
        }
        // Trigger node graph update
        requestPaint()
    }
}
```

## Python Integration

### Kasugai Socket Handler

The kasugai socket server automatically forwards eBPF events to all WebSocket clients. No additional code needed in `kasugai_socket.py` — events are broadcast via the persistent event stream.

### Custom Event Processing

```python
# In your Python module
import socket
import json

def read_ebpf_events():
    """Read last 10 events from eBPF direct socket"""
    sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    sock.connect("/tmp/shigurui-ebpf.sock")
    
    events = []
    for line in sock.makefile():
        event = json.loads(line.strip())
        events.append(event)
    
    sock.close()
    return events
```

## Security Considerations

### Capabilities

The eBPF daemon requires `CAP_NET_ADMIN` to:
- Add TC clsact qdisc
- Attach TC classifier programs
- Load eBPF programs

### Systemd Hardening

The provided systemd service uses:
- `AmbientCapabilities=CAP_NET_ADMIN` (minimal privilege)
- `NoNewPrivileges=true` (prevent privilege escalation)
- `ProtectSystem=strict` (read-only filesystem)
- `ProtectHome=true` (no home directory access)
- `PrivateTmp=true` (isolated /tmp)

### Data Privacy

- Only packet metadata is captured (no payload)
- Loopback traffic is filtered out
- Events are broadcast to local Unix sockets only
- No network exposure

## Performance

### Overhead

- eBPF program: ~100 CPU cycles per packet
- Perf event processing: ~1-2% CPU at 10k pps
- Memory: ~10 MB resident

### Tuning

Adjust perf buffer size in `ipc.rs`:

```rust
let mut buf = perf_array.open(cpu_id, Some(4096))?;  // 4KB per CPU
```

## Troubleshooting

### No events appearing

1. Check daemon is running: `systemctl status shigurui-ebpf`
2. Check logs: `journalctl -u shigurui-ebpf -f`
3. Verify TC attachment: `tc filter show dev <iface> egress`
4. Test with traffic: `curl https://1.1.1.1`

### Permission denied

- Ensure running as root or with `CAP_NET_ADMIN`
- Check systemd service has `AmbientCapabilities=CAP_NET_ADMIN`

### eBPF program load failed

- Verify kernel version: `uname -r` (need 5.10+)
- Check BTF support: `ls /sys/kernel/btf/vmlinux`
- Recompile eBPF program: `./compile.sh`

## Development

### Hot Reload

```bash
# Terminal 1: Watch logs
sudo journalctl -u shigurui-ebpf -f

# Terminal 2: Rebuild and restart
make clean && make build
sudo systemctl restart shigurui-ebpf
```

### Debug Mode

```bash
# Run with verbose logging
sudo RUST_LOG=debug ./target/debug/shigurui-ebpf
```

### Event Injection (Testing)

```bash
# Generate test traffic
curl https://1.1.1.1
ping -c 5 8.8.8.8

# Read events directly
nc -U /tmp/shigurui-ebpf.sock
```

## Future Enhancements

- [ ] IPv6 support
- [ ] Policy enforcement (block verdicts)
- [ ] DNS resolution for IPs
- [ ] GeoIP lookup integration
- [ ] Connection state tracking
- [ ] Bandwidth accounting
- [ ] Process tree correlation
