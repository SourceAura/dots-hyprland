#!/usr/bin/env bash
# install.sh — Install eBPF daemon as systemd service
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root (for systemd installation)"
   exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "[install] Building eBPF daemon..."
./compile.sh
cargo build --release

echo "[install] Installing binary to /usr/local/bin/shigurui-ebpf"
cp target/release/shigurui-ebpf /usr/local/bin/shigurui-ebpf
chmod +x /usr/local/bin/shigurui-ebpf

echo "[install] Installing systemd service"
cp shigurui-ebpf.service /etc/systemd/system/shigurui-ebpf.service
systemctl daemon-reload

echo "[install] ✓ Installation complete"
echo ""
echo "To start the service:"
echo "  sudo systemctl start shigurui-ebpf"
echo ""
echo "To enable on boot:"
echo "  sudo systemctl enable shigurui-ebpf"
echo ""
echo "To view logs:"
echo "  sudo journalctl -u shigurui-ebpf -f"
