#!/usr/bin/env bash
# compile.sh — Compile eBPF C program to .o object
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "[ebpf] Compiling egress.bpf.c → egress.bpf.o"

clang -O2 -target bpf \
  -c src/ebpf/egress.bpf.c \
  -o src/ebpf/egress.bpf.o \
  -I/usr/include/bpf \
  -I/usr/include/linux \
  -g

echo "[ebpf] ✓ Compiled: src/ebpf/egress.bpf.o"
echo "[ebpf] Build with: cargo build --release"
