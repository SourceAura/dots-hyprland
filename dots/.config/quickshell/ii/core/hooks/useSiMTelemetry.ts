// core/hooks/useSiMTelemetry.ts
// Sun iN Moon (SiM) — High-Fidelity DankMaterial Telemetry Hook
//
// Role: SAGE (◈) — Orchestrates real-time system state & telemetry streams.

import { useState, useEffect, useCallback, useRef } from 'react';

export interface ShroudStatus {
  status: 'Secure' | 'Exposed';
  tunnel: boolean;
  killswitch: boolean;
  ipv6_disabled: boolean;
  latencyMs: number;
}

export interface ActiveSibyls {
  eye: boolean;
  phantom: boolean;
  blade: boolean;
  sage: boolean;
  shroud: boolean;
  forge: boolean;
  mirror: boolean;
}

export interface Vitals {
  cpu: number;
  memory: number;
}

export interface TelemetryData {
  shroud_status: ShroudStatus;
  active_sibyls: ActiveSibyls;
  current_breathing_style: 'celestial' | 'moon' | 'sun';
  vitals: Vitals;
  active_command: string | null;
}

const API_BASE = 'http://127.0.0.1:8765/api';
const WS_URL = 'ws://127.0.0.1:8765/intelligence-feed';

const INITIAL_STATE: TelemetryData = {
  shroud_status: {
    status: 'Exposed',
    tunnel: false,
    killswitch: false,
    ipv6_disabled: false,
    latencyMs: 15, // default baseline
  },
  active_sibyls: {
    eye: false,
    phantom: false,
    blade: false,
    sage: false,
    shroud: false,
    forge: false,
    mirror: false,
  },
  current_breathing_style: 'moon',
  vitals: {
    cpu: 0.0,
    memory: 0.0,
  },
  active_command: null,
};

export function useSiMTelemetry() {
  const [telemetry, setTelemetry] = useState<TelemetryData>(INITIAL_STATE);
  const [isConnected, setIsConnected] = useState(false);
  const wsRef = useRef<WebSocket | null>(null);
  const sibylTimeoutsRef = useRef<{ [key: string]: NodeJS.Timeout }>({});

  // ── Sync Initial State from REST Endpoints ──────────────────────────
  const syncTelemetryState = useCallback(async () => {
    try {
      // 1. Shroud Posture Check
      const shroudRes = await fetch(`${API_BASE}/shroud`);
      if (shroudRes.ok) {
        const data = await shroudRes.json();
        setTelemetry((prev) => ({
          ...prev,
          shroud_status: {
            status: data.status || 'Exposed',
            tunnel: data.tunnel || false,
            killswitch: data.killswitch || false,
            ipv6_disabled: data.ipv6_disabled || false,
            latencyMs: data.tunnel ? 120 + Math.random() * 40 : 12 + Math.random() * 8, // simulated Tor latency
          },
        }));
      }

      // 2. Active Style Check
      const styleRes = await fetch(`${API_BASE}/style`);
      if (styleRes.ok) {
        const data = await styleRes.json();
        setTelemetry((prev) => ({
          ...prev,
          current_breathing_style: data.name || 'moon',
        }));
      }

      // 3. Vitals Check
      const healthRes = await fetch(`${API_BASE}/health/status`);
      if (healthRes.ok) {
        const data = await healthRes.json();
        if (data.components) {
          const cpuVal = parseFloat(data.components.cpu) || 0;
          const memVal = parseFloat(data.components.memory) || 0;
          setTelemetry((prev) => ({
            ...prev,
            vitals: { cpu: cpuVal, memory: memVal },
          }));
        }
      }
    } catch (err) {
      console.warn('[useSiMTelemetry] REST state sync failed:', err);
    }
  }, []);

  // ── Flash active Sibyl segment ─────────────────────────────────────
  const flashSibyl = useCallback((sibyl: keyof ActiveSibyls) => {
    // Clear any existing timeout for this Sibyl
    if (sibylTimeoutsRef.current[sibyl]) {
      clearTimeout(sibylTimeoutsRef.current[sibyl]);
    }

    setTelemetry((prev) => ({
      ...prev,
      active_sibyls: {
        ...prev.active_sibyls,
        [sibyl]: true,
      },
    }));

    // Keep highlighted for 2.5 seconds to show visual active query phase
    sibylTimeoutsRef.current[sibyl] = setTimeout(() => {
      setTelemetry((prev) => ({
        ...prev,
        active_sibyls: {
          ...prev.active_sibyls,
          [sibyl]: false,
        },
      }));
    }, 2500);
  }, []);

  // ── Handle incoming WS payloads ────────────────────────────────────
  const handleWebSocketMessage = useCallback((event: MessageEvent) => {
    try {
      const msg = JSON.parse(event.data);
      if (!msg || !msg.type) return;

      switch (msg.type) {
        case 'STYLE_CHANGED':
          setTelemetry((prev) => ({
            ...prev,
            current_breathing_style: msg.style || 'moon',
          }));
          break;

        case 'pulse':
          if (msg.vitals) {
            setTelemetry((prev) => ({
              ...prev,
              vitals: {
                cpu: msg.vitals.cpu ?? 0.0,
                memory: msg.vitals.memory ?? 0.0,
              },
            }));
          }
          break;

        case 'GOVERNOR_STATE':
          if (msg.load_percent !== undefined) {
            setTelemetry((prev) => ({
              ...prev,
              vitals: {
                ...prev.vitals,
                cpu: msg.load_percent,
              },
            }));
          }
          break;

        case 'SUBSTRATE_STREAM':
          if (msg.stream_type === 'auth') {
            const authData = msg.data;
            if (authData) {
              setTelemetry((prev) => ({
                ...prev,
                active_command: authData.command || prev.active_command,
              }));

              // Scan thoughts to flash active querying Sibyls
              const thoughts = authData.thoughts || [];
              thoughts.forEach((thought: string) => {
                const match = thought.match(/^\[([A-Z]+)\]/);
                if (match && match[1]) {
                  const sibylName = match[1].toLowerCase() as keyof ActiveSibyls;
                  if (INITIAL_STATE.active_sibyls[sibylName] !== undefined) {
                    flashSibyl(sibylName);
                  }
                }
              });
            }
          } else if (msg.stream_type === 'exit') {
            setTelemetry((prev) => ({
              ...prev,
              active_command: null,
            }));
          }
          break;

        case 'SHROUD_BREACH':
          setTelemetry((prev) => ({
            ...prev,
            shroud_status: {
              ...prev.shroud_status,
              status: 'Exposed',
              latencyMs: 15,
            },
          }));
          break;

        default:
          break;
      }
    } catch (e) {
      // Ignore unparseable raw frame streams
    }
  }, [flashSibyl]);

  // ── Establish WebSocket Connection ────────────────────────────────
  useEffect(() => {
    // Perform initial sync
    syncTelemetryState();

    // Poll shroud status every 5 seconds
    const interval = setInterval(syncTelemetryState, 5000);

    // WebSocket logic
    const connectWS = () => {
      console.log('[useSiMTelemetry] Initializing WebSocket client connection:', WS_URL);
      const ws = new WebSocket(WS_URL);

      ws.onopen = () => {
        setIsConnected(true);
        console.log('[useSiMTelemetry] WebSocket connected successfully');
      };

      ws.onmessage = handleWebSocketMessage;

      ws.onerror = (e) => {
        console.warn('[useSiMTelemetry] WebSocket encountered connection error:', e);
      };

      ws.onclose = () => {
        setIsConnected(false);
        wsRef.current = null;
        console.warn('[useSiMTelemetry] Connection closed. Attempting re-ignition in 4s...');
        setTimeout(connectWS, 4000);
      };

      wsRef.current = ws;
    };

    connectWS();

    return () => {
      clearInterval(interval);
      if (wsRef.current) {
        wsRef.current.close();
      }
      // Clear all active flash timeouts
      Object.values(sibylTimeoutsRef.current).forEach(clearTimeout);
    };
  }, [syncTelemetryState, handleWebSocketMessage]);

  // ── Tactical Actions ───────────────────────────────────────────────
  const toggleShroud = useCallback(async () => {
    try {
      const res = await fetch(`${API_BASE}/shroud/toggle`, { method: 'POST' });
      if (res.ok) {
        await syncTelemetryState();
      }
    } catch (err) {
      console.error('[useSiMTelemetry] Failed to toggle Shroud tunnel:', err);
    }
  }, [syncTelemetryState]);

  const resetSystem = useCallback(async () => {
    try {
      const res = await fetch(`${API_BASE}/health/reset`, { method: 'POST' });
      if (res.ok) {
        console.log('[useSiMTelemetry] SiM reset signal accepted');
        await syncTelemetryState();
      }
    } catch (err) {
      console.error('[useSiMTelemetry] Failed to reset SiM:', err);
    }
  }, [syncTelemetryState]);

  const toggleStyle = useCallback(async (styleName: 'celestial' | 'moon' | 'sun') => {
    try {
      const res = await fetch(`${API_BASE}/style`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ name: styleName }),
      });
      if (res.ok) {
        await syncTelemetryState();
      }
    } catch (err) {
      console.error('[useSiMTelemetry] Failed to transition Breathing Style:', err);
    }
  }, [syncTelemetryState]);

  return {
    telemetry,
    isConnected,
    toggleShroud,
    resetSystem,
    toggleStyle,
    sync: syncTelemetryState,
  };
}
