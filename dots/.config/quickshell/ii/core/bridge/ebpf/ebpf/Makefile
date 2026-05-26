# Makefile for ASE eBPF Telemetry Bridge

.PHONY: all clean compile build install uninstall test

all: compile build

# Compile eBPF C program to .o object
compile:
	@echo "[ebpf] Compiling eBPF program..."
	@./compile.sh

# Build Rust userspace daemon
build: compile
	@echo "[ebpf] Building Rust daemon..."
	@cargo build --release

# Install as systemd service (requires root)
install: build
	@echo "[ebpf] Installing (requires root)..."
	@sudo ./install.sh

# Uninstall systemd service
uninstall:
	@echo "[ebpf] Uninstalling..."
	@sudo systemctl stop ase-ebpf || true
	@sudo systemctl disable ase-ebpf || true
	@sudo rm -f /etc/systemd/system/ase-ebpf.service
	@sudo rm -f /usr/local/bin/ase-ebpf
	@sudo systemctl daemon-reload
	@echo "[ebpf] ✓ Uninstalled"

# Clean build artifacts
clean:
	@echo "[ebpf] Cleaning..."
	@cargo clean
	@rm -f src/ebpf/egress.bpf.o
	@echo "[ebpf] ✓ Clean"

# Test build (no install)
test: compile
	@echo "[ebpf] Test build..."
	@cargo build
	@echo "[ebpf] ✓ Test build successful"
	@echo "[ebpf] Run with: sudo ./target/debug/ase-ebpf"

# Development: compile + run (requires root)
dev: compile
	@echo "[ebpf] Running in dev mode (requires root)..."
	@cargo build
	@sudo RUST_LOG=info ./target/debug/ase-ebpf
