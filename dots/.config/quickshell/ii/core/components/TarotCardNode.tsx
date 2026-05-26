// core/components/TarotCardNode.tsx
// Sun iN Moon (SiM) — Atelier WarRoom Tarot Card Node Component

import React, { useRef } from 'react';
import { NodeProps } from '@xyflow/react';
import { TarotCardData } from '../types/tarot';
import './TarotCard.css'; // Glassmorphic / 3D tilt styles

export const TarotCardNode: React.FC<NodeProps<TarotCardData>> = ({ data }) => {
  const cardRef = useRef<HTMLDivElement>(null);

  const handleMouseMove = (e: React.MouseEvent<HTMLDivElement>) => {
    if (!cardRef.current || data.isFlipped) return;
    const rect = cardRef.current.getBoundingClientRect();
    const x = e.clientX - rect.left - rect.width / 2;
    const y = e.clientY - rect.top - rect.height / 2;
    
    // Smooth 3D tilt calculation
    const rotateX = -(y / (rect.height / 2)) * 12; // Cap at 12deg
    const rotateY = (x / (rect.width / 2)) * 12;

    cardRef.current.style.transform = `perspective(1000px) rotateX(${rotateX}deg) rotateY(${rotateY}deg)`;
  };

  const handleMouseLeave = () => {
    if (!cardRef.current || data.isFlipped) return;
    cardRef.current.style.transform = 'perspective(1000px) rotateX(0deg) rotateY(0deg)';
  };

  return (
    <div 
      className={`tarot-node-container ${data.isFlipped ? 'flipped' : ''}`}
      onMouseMove={handleMouseMove}
      onMouseLeave={handleMouseLeave}
    >
      <div 
        ref={cardRef} 
        className={`tarot-card ${data.fold}`}
        style={{ '--glow': data.visuals.glowColor } as React.CSSProperties}
      >
        {/* Card Front: Iridescent Rune Sigil */}
        <div className="card-face card-front">
          <div className="glass-reflection" />
          <div className="rune-sigil">{data.fold.substring(0, 2).toUpperCase()}</div>
          <div className="label-spine">{data.label}</div>
        </div>

        {/* Card Back: Telemetry Terminal */}
        <div className="card-face card-back">
          <div className="telemetry-header">
            <span className="status-indicator active" />
            <span className="node-title">{data.label}</span>
          </div>
          <div className="telemetry-body">
            <pre className="command-incantation">{data.commands.incantation}</pre>
            <div className="metrics-row">
              <div>CPU: {data.metrics.cpuPercent || 0}%</div>
              <div>IOCs: {data.metrics.indicatorsFound || 0}</div>
            </div>
            <div className="stream-output">
              {data.commands.stdoutTail.map((line, idx) => (
                <div key={idx} className="terminal-line">{line}</div>
              ))}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};
