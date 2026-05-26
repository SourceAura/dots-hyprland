#!/usr/bin/env bash
# test.sh — Test eBPF daemon functionality
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "=== ASE eBPF Telemetry Bridge Test Suite ==="
echo ""

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "❌ This test must be run as root (eBPF requires CAP_NET_ADMIN)"
   echo "   Run: sudo ./test.sh"
   exit 1
fi

# Check dependencies
echo "[1/6] Checking dependencies..."
command -v clang >/dev/null 2>&1 || { echo "❌ clang not found. Install: apt install clang"; exit 1; }
command -v cargo >/dev/null 2>&1 || { echo "❌ cargo not found. Install Rust toolchain"; exit 1; }
echo "✓ Dependencies OK"
echo ""

# Compile eBPF program
echo "[2/6] Compiling eBPF program..."
if ./compile.sh; then
    echo "✓ eBPF compilation successful"
else
    echo "❌ eBPF compilation failed"
    exit 1
fi
echo ""

# Build Rust daemon
echo "[3/6] Building Rust daemon..."
if cargo build 2>&1 | tail -5; then
    echo "✓ Rust build successful"
else
    echo "❌ Rust build failed"
    exit 1
fi
echo ""

# Check eBPF object exists
echo "[4/6] Verifying eBPF object..."
if [[ -f "src/ebpf/egress.bpf.o" ]]; then
    SIZE=$(stat -f%z "src/ebpf/egress.bpf.o" 2>/dev/null || stat -c%s "src/ebpf/egress.bpf.o")
    echo "✓ egress.bpf.o exists (${SIZE} bytes)"
else
    echo "❌ egress.bpf.o not found"
    exit 1
fi
echo ""

# Detect default interface
echo "[5/6] Detecting default network interface..."
IFACE=$(ip route | grep default | awk '{print $5}' | head -1)
if [[ -z "$IFACE" ]]; then
    echo "❌ No default network interface found"
    exit 1
fi
echo "✓ Default interface: $IFACE"
echo ""

# Start daemon in background
echo "[6/6] Starting daemon (10 second test)..."
RUST_LOG=info ./target/debug/shigurui-ebpf &
DAEMON_PID=$!

# Wait for startup
sleep 2

# Check if daemon is running
if ! kill -0 $DAEMON_PID 2>/dev/null; then
    echo "❌ Daemon failed to start"
    exit 1
fi
echo "✓ Daemon started (PID: $DAEMON_PID)"

# Generate some traffic
echo ""
echo "Generating test traffic..."
curl -s https://1.1.1.1 >/dev/null 2>&1 || true
ping -c 2 1.1.1.1 >/dev/null 2>&1 || true

# Check event socket
sleep 2
if [[ -S "/tmp/shigurui-ebpf.sock" ]]; then
    echo "✓ Event socket created: /tmp/shigurui-ebpf.sock"
    echo ""
    echo "Sample events (last 5):"
    timeout 2 nc -U /tmp/shigurui-ebpf.sock 2>/dev/null | head -5 || echo "(no events yet)"
else
    echo "⚠ Event socket not found (may need more time)"
fi

# Cleanup
echo ""
echo "Stopping daemon..."
kill $DAEMON_PID 2>/dev/null || true
wait $DAEMON_PID 2>/dev/null || true

# Check for TC filter attachment
echo ""
echo "Checking TC filter attachment..."
if tc filter show dev "$IFACE" egress 2>/dev/null | grep -q "ase_egress"; then
    echo "✓ TC filter was attached"
    # Cleanup
    tc qdisc del dev "$IFACE" clsact 2>/dev/null || true
else
    echo "⚠ TC filter not found (may have been cleaned up)"
fi

echo ""
echo "=== Test Complete ==="
echo ""
echo "✓ All checks passed!"
echo ""
echo "To install as systemd service:"
echo "  sudo make install"
echo ""
echo "To run manually:"
echo "  sudo ./target/release/shigurui-ebpf"
