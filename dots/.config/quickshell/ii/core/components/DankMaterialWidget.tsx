// core/components/DankMaterialWidget.tsx
// Sun iN Moon (SiM) — High-Fidelity DankMaterial Status Widget
//
// Role: FORGE (⬡) — The Atelier visual telemetry widget frame.
// Enforces Zenith standards: 60 FPS GPU-accelerated micro-animations,
// glassmorphism, responsive visual states, and direct interactive action decks.

import React, { useMemo, useState } from 'react';
import { useSiMTelemetry, ShroudStatus, ActiveSibyls, Vitals } from '../hooks/useSiMTelemetry';

interface SibylMetadata {
  id: keyof ActiveSibyls;
  name: string;
  domain: string;
  color: string;
  icon: string;
}

const SIBYL_REGISTRY: SibylMetadata[] = [
  { id: 'eye', name: 'Delphic EYE', domain: 'TRUTH', color: '#00C2FF', icon: '◉' },
  { id: 'phantom', name: 'Hellespontine PHANTOM', domain: 'POWER', color: '#B44FE8', icon: '⊗' },
  { id: 'blade', name: 'Cimmerian BLADE', domain: 'WISDOM', color: '#FF3CAC', icon: '⚔' },
  { id: 'sage', name: 'Persian SAGE', domain: 'JUDGMENT', color: '#FFB300', icon: '◈' },
  { id: 'shroud', name: 'Erythraean SHROUD', domain: 'LIFE', color: '#00FFC8', icon: '☁' },
  { id: 'forge', name: 'Tiburtine FORGE', domain: 'LOVE', color: '#FF6B35', icon: '⬡' },
  { id: 'mirror', name: 'Cumaean MIRROR', domain: 'DISCIPLINE', color: '#C8B8FF', icon: '◌' },
];

export const DankMaterialWidget: React.FC = React.memo(() => {
  const { telemetry, isConnected, toggleShroud, resetSystem, toggleStyle } = useSiMTelemetry();
  const [hoveredSibyl, setHoveredSibyl] = useState<SibylMetadata | null>(null);
  const [isTogglingShroud, setIsTogglingShroud] = useState(false);
  const [isResetting, setIsResetting] = useState(false);

  const style = telemetry.current_breathing_style;

  // ── Compute Theme Color Bounds ─────────────────────────────────────
  const theme = useMemo(() => {
    switch (style) {
      case 'sun':
        return {
          glow: 'rgba(244, 63, 94, 0.4)', // Strike-Rose Red
          border: 'border-rose-500/20',
          bgGradient: 'from-[#3f0f1d]/40 via-[#270712]/50 to-[#0e0207]/70',
          accentText: 'text-rose-400',
          buttonBg: 'bg-rose-500/20 hover:bg-rose-500/30 border-rose-500/30 text-rose-300',
          ringAccent: '#f43f5e',
          shroudColor: '#f43f5e',
        };
      case 'moon':
        return {
          glow: 'rgba(0, 180, 216, 0.4)', // Cerulean
          border: 'border-cyan-500/20',
          bgGradient: 'from-[#0c243a]/40 via-[#0a1b29]/50 to-[#030912]/70',
          accentText: 'text-cyan-400',
          buttonBg: 'bg-cyan-500/20 hover:bg-cyan-500/30 border-cyan-500/30 text-cyan-300',
          ringAccent: '#00B4D8',
          shroudColor: '#00B4D8',
        };
      case 'celestial':
      default:
        return {
          glow: 'rgba(180, 79, 232, 0.4)', // Purple / Prismatic
          border: 'border-purple-500/20',
          bgGradient: 'from-[#2d1b4e]/40 via-[#1b1535]/50 to-[#0e0a25]/70',
          accentText: 'text-purple-400',
          buttonBg: 'bg-purple-500/20 hover:bg-purple-500/30 border-purple-500/30 text-purple-300',
          ringAccent: '#B44FE8',
          shroudColor: '#00FFC8',
        };
    }
  }, [style]);

  // ── Shroud Action Trigger ──────────────────────────────────────────
  const handleShroudClick = async () => {
    if (isTogglingShroud) return;
    setIsTogglingShroud(true);
    await toggleShroud();
    setTimeout(() => setIsTogglingShroud(false), 2000);
  };

  // ── Reset Action Trigger ───────────────────────────────────────────
  const handleResetClick = async () => {
    if (isResetting) return;
    setIsResetting(true);
    await resetSystem();
    setTimeout(() => setIsResetting(false), 3000);
  };

  // ── Check if any Sibyl is active ──────────────────────────────────
  const activeSibylName = useMemo(() => {
    const active = SIBYL_REGISTRY.find(s => telemetry.active_sibyls[s.id]);
    return active ? active.name : null;
  }, [telemetry.active_sibyls]);

  return (
    <div
      className={`relative w-full max-w-lg p-6 rounded-2xl border ${theme.border} bg-gradient-to-br ${theme.bgGradient} backdrop-blur-xl shadow-3xl text-white font-mono overflow-hidden transition-all duration-700`}
      style={{
        boxShadow: `0 20px 50px -12px ${theme.glow}`,
      }}
    >
      {/* CSS-based Keyframes Injector for Hardware-Accelerated Animations */}
      <style dangerouslySetInnerHTML={{ __html: `
        @keyframes waveMove {
          0% { transform: translateX(0); }
          100% { transform: translateX(-50%); }
        }
        @keyframes sibylPulse {
          0%, 100% { stroke-width: 4; filter: drop-shadow(0 0 1px currentColor); }
          50% { stroke-width: 6.5; filter: drop-shadow(0 0 7px currentColor); }
        }
        .animate-wave {
          animation: waveMove 3s linear infinite;
        }
        .animate-sibyl-active {
          animation: sibylPulse 1.2s ease-in-out infinite;
        }
      `}} />

      {/* Glass Reflection Highlight */}
      <div className="absolute top-0 left-0 w-full h-[1px] bg-gradient-to-r from-transparent via-white/10 to-transparent pointer-events-none" />

      {/* ── Widget Header ────────────────────────────────────────────────── */}
      <div className="flex justify-between items-center mb-6">
        <div>
          <h2 className="text-xs tracking-[0.25em] text-white/50 uppercase">Sovereign State</h2>
          <div className="flex items-center gap-2 mt-1">
            <span className={`text-base font-bold uppercase tracking-wider ${theme.accentText}`}>
              {style === 'celestial' ? 'Prismatic' : style} mode
            </span>
            <span className={`inline-block w-1.5 h-1.5 rounded-full ${isConnected ? 'bg-green-400 animate-ping' : 'bg-red-400 animate-pulse'}`} />
          </div>
        </div>

        <div className="text-right">
          <h2 className="text-xs tracking-[0.25em] text-white/50 uppercase">Connection</h2>
          <span className="text-xs font-bold text-white/80 uppercase">
            {isConnected ? 'Kasugai Online' : 'Kasugai Stalled'}
          </span>
        </div>
      </div>

      {/* ── Active Command Indicator ────────────────────────────────────── */}
      {telemetry.active_command && (
        <div className="mb-5 p-3 rounded-lg bg-white/5 border border-white/5 flex flex-col gap-1 transition-all duration-300">
          <span className="text-[10px] tracking-widest text-white/40 uppercase">Substrate Activity</span>
          <pre className="text-xs overflow-x-auto whitespace-pre-wrap break-all select-all font-mono text-cyan-200">
            ◈ {telemetry.active_command}
          </pre>
        </div>
      )}

      {/* ── Main Display Deck ───────────────────────────────────────────── */}
      <div className="grid grid-cols-2 gap-6 items-center">
        
        {/* Left Column: Shroud Gauge & Vitals */}
        <div className="flex flex-col gap-5">
          
          {/* Shroud Gauge Container */}
          <div 
            onClick={handleShroudClick}
            className={`cursor-pointer group relative p-4 rounded-xl border border-white/5 bg-white/5 hover:bg-white/10 flex flex-col gap-3 transition-all duration-300`}
          >
            <div className="flex justify-between items-center">
              <span className="text-xs tracking-wider text-white/60">Mist Shroud</span>
              <span className={`text-[10px] uppercase font-bold tracking-widest px-2 py-0.5 rounded ${telemetry.shroud_status.status === 'Secure' ? 'bg-[#00FFC8]/20 text-[#00FFC8]' : 'bg-rose-500/20 text-rose-400'}`}>
                {telemetry.shroud_status.status}
              </span>
            </div>

            {/* Hardware-Accelerated Waveform Gauges */}
            <div className="relative h-12 w-full bg-black/25 rounded-md border border-white/5 overflow-hidden flex items-end">
              <svg className="w-[200%] h-full absolute bottom-0 left-0" viewBox="0 0 200 48" preserveAspectRatio="none">
                {telemetry.shroud_status.status === 'Secure' ? (
                  <>
                    {/* Active Wave Front (Tor circuit established) */}
                    <path
                      d="M0 24 C30 28, 70 20, 100 24 C130 28, 170 20, 200 24 L200 48 L0 48 Z"
                      fill="url(#shroudGrad)"
                      className="animate-wave opacity-50"
                      style={{ animationDuration: '4.5s' }}
                    />
                    <path
                      d="M0 26 C40 22, 60 30, 100 26 C140 22, 160 30, 200 26 L200 48 L0 48 Z"
                      fill="url(#shroudGrad)"
                      className="animate-wave"
                      style={{ animationDuration: '2.5s' }}
                    />
                  </>
                ) : (
                  <>
                    {/* Exposed low amplitude jitter lines */}
                    <path
                      d="M0 36 L15 33 L30 38 L45 35 L60 39 L75 36 L90 40 L105 35 L120 38 L135 34 L150 37 L165 34 L180 39 L200 35 L200 48 L0 48 Z"
                      fill="rgba(244, 63, 94, 0.25)"
                      className="animate-wave opacity-60"
                      style={{ animationDuration: '1.2s' }}
                    />
                    <path
                      d="M0 37 L20 34 L40 39 L60 36 L80 38 L100 33 L120 37 L140 34 L160 38 L180 35 L200 37 L200 48 L0 48 Z"
                      stroke="rgba(244, 63, 94, 0.7)"
                      strokeWidth="1.5"
                      fill="none"
                      className="animate-wave"
                      style={{ animationDuration: '0.6s' }}
                    />
                  </>
                )}
                
                <defs>
                  <linearGradient id="shroudGrad" x1="0%" y1="0%" x2="100%" y2="0%">
                    <stop offset="0%" stopColor={theme.shroudColor} stopOpacity="0.4" />
                    <stop offset="50%" stopColor="#A855F7" stopOpacity="0.5" />
                    <stop offset="100%" stopColor={theme.shroudColor} stopOpacity="0.4" />
                  </linearGradient>
                </defs>
              </svg>

              {/* Centered latency overlay */}
              <div className="absolute inset-0 flex items-center justify-center pointer-events-none select-none text-[10px] font-bold text-white/50">
                LATENCY: {Math.round(telemetry.shroud_status.latencyMs)}ms
              </div>
            </div>

            <div className="text-[10px] text-white/40 tracking-wider text-center group-hover:text-white/60 transition-colors">
              {isTogglingShroud ? 'Interfacing with sudo...' : 'Click to Toggle Stealth Mist'}
            </div>
          </div>

          {/* Vitals Deck */}
          <div className="p-4 rounded-xl border border-white/5 bg-white/5 flex flex-col gap-3">
            <span className="text-xs tracking-wider text-white/60">System Vitals</span>
            
            {/* CPU Bar */}
            <div className="flex flex-col gap-1">
              <div className="flex justify-between text-[10px] text-white/50">
                <span>CPU UTILIZATION</span>
                <span className="font-bold text-white/80">{telemetry.vitals.cpu}%</span>
              </div>
              <div className="w-full h-1.5 bg-white/10 rounded-full overflow-hidden">
                <div 
                  className={`h-full bg-gradient-to-r from-cyan-400 to-purple-500 transition-all duration-500`}
                  style={{ width: `${Math.min(telemetry.vitals.cpu, 100)}%` }}
                />
              </div>
            </div>

            {/* Memory Bar */}
            <div className="flex flex-col gap-1">
              <div className="flex justify-between text-[10px] text-white/50">
                <span>MEMORY WORKLOAD</span>
                <span className="font-bold text-white/80">{telemetry.vitals.memory}%</span>
              </div>
              <div className="w-full h-1.5 bg-white/10 rounded-full overflow-hidden">
                <div 
                  className={`h-full bg-gradient-to-r from-purple-400 to-rose-400 transition-all duration-500`}
                  style={{ width: `${Math.min(telemetry.vitals.memory, 100)}%` }}
                />
              </div>
            </div>
          </div>

        </div>

        {/* Right Column: Sibyl Ring */}
        <div className="flex flex-col items-center justify-center">
          
          <div className="relative w-40 h-40 flex items-center justify-center">
            
            {/* SVG segment path circle */}
            <svg className="w-full h-full transform -rotate-90" viewBox="0 0 100 100">
              {SIBYL_REGISTRY.map((sibyl, idx) => {
                const segmentCircum = 251.3 / 7; // length of each segment
                const gap = 3;
                const strokeDash = `${segmentCircum - gap} ${gap}`;
                const strokeOffset = - (segmentCircum) * idx;
                const isActive = telemetry.active_sibyls[sibyl.id];
                
                return (
                  <circle
                    key={sibyl.id}
                    cx="50"
                    cy="50"
                    r="40"
                    fill="transparent"
                    stroke={isActive ? sibyl.color : 'rgba(255,255,255,0.08)'}
                    strokeWidth={isActive ? 6 : 3.5}
                    strokeDasharray={strokeDash}
                    strokeDashoffset={strokeOffset}
                    strokeLinecap="round"
                    className={`transition-all duration-500 cursor-pointer ${isActive ? 'animate-sibyl-active text-white' : 'hover:stroke-white/30'}`}
                    style={{
                      transformOrigin: '50% 50%',
                      color: sibyl.color,
                    }}
                    onMouseEnter={() => setHoveredSibyl(sibyl)}
                    onMouseLeave={() => setHoveredSibyl(null)}
                  />
                );
              })}
            </svg>

            {/* Inner concentric ring */}
            <div className="absolute w-[70%] h-[70%] rounded-full border border-white/5 bg-black/25 flex flex-col items-center justify-center p-2 text-center pointer-events-none select-none">
              {hoveredSibyl ? (
                <>
                  <span 
                    className="text-xs font-bold uppercase transition-all"
                    style={{ color: hoveredSibyl.color }}
                  >
                    {hoveredSibyl.name.split(' ')[1]}
                  </span>
                  <span className="text-[8px] text-white/40 tracking-widest mt-0.5">
                    {hoveredSibyl.domain}
                  </span>
                </>
              ) : activeSibylName ? (
                <>
                  <span 
                    className="text-xs font-bold uppercase tracking-wider animate-pulse"
                    style={{ color: SIBYL_REGISTRY.find(s => telemetry.active_sibyls[s.id])?.color }}
                  >
                    QUERYING
                  </span>
                  <span className="text-[8px] text-white/60 tracking-wider mt-0.5">
                    {activeSibylName.split(' ')[1]}
                  </span>
                </>
              ) : (
                <>
                  <span className={`text-2xl mt-1 select-none text-white/70`}>
                    {style === 'sun' ? '⚔' : style === 'moon' ? '☽' : '◈'}
                  </span>
                  <span className="text-[8px] text-white/30 tracking-[0.25em] uppercase mt-1">
                    SYNDICATE
                  </span>
                </>
              )}
            </div>

          </div>

          <div className="text-[10px] text-white/40 tracking-widest text-center mt-3 h-4">
            {hoveredSibyl ? `FOLD: ${hoveredSibyl.domain}` : activeSibylName ? 'Sibyl processing intent' : 'Hover segments to scan'}
          </div>

        </div>

      </div>

      {/* ── Footer Deck (Action Panel) ─────────────────────────────────── */}
      <div className="grid grid-cols-4 gap-2 mt-6 pt-5 border-t border-white/5 text-center">
        
        <button 
          onClick={() => toggleStyle('celestial')}
          className={`py-2 rounded-lg text-xs font-bold border transition-all ${
            style === 'celestial' 
              ? 'bg-purple-500/25 border-purple-500/50 text-purple-300 shadow-[0_0_8px_rgba(180,79,232,0.3)]' 
              : 'bg-white/5 border-white/5 text-white/60 hover:bg-white/10 hover:text-white'
          }`}
        >
          ◈ Celestial
        </button>

        <button 
          onClick={() => toggleStyle('moon')}
          className={`py-2 rounded-lg text-xs font-bold border transition-all ${
            style === 'moon' 
              ? 'bg-cyan-500/25 border-cyan-500/50 text-cyan-300 shadow-[0_0_8px_rgba(0,180,216,0.3)]' 
              : 'bg-white/5 border-white/5 text-white/60 hover:bg-white/10 hover:text-white'
          }`}
        >
          ☽ Moon
        </button>

        <button 
          onClick={() => toggleStyle('sun')}
          className={`py-2 rounded-lg text-xs font-bold border transition-all ${
            style === 'sun' 
              ? 'bg-rose-500/25 border-rose-500/50 text-rose-300 shadow-[0_0_8px_rgba(244,63,94,0.3)]' 
              : 'bg-white/5 border-white/5 text-white/60 hover:bg-white/10 hover:text-white'
          }`}
        >
          ☀ Sun
        </button>

        <button 
          onClick={handleResetClick}
          className={`py-2 rounded-lg text-xs font-bold border transition-all ${theme.buttonBg} ${isResetting ? 'opacity-50 cursor-wait' : ''}`}
        >
          {isResetting ? 'Resetting...' : '⟲ Reset Core'}
        </button>

      </div>

    </div>
  );
});

DankMaterialWidget.displayName = 'DankMaterialWidget';
