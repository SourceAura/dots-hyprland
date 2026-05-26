// core/types/tarot.ts
// Sun iN Moon (SiM) — Atelier WarRoom TypeScript Definitions

export type FoldType = 'eye' | 'phantom' | 'blade' | 'sage' | 'shroud' | 'forge' | 'mirror';
export type ExecState = 'idle' | 'incanting' | 'resolved' | 'failed';

export interface TarotCardData {
  id: string;
  label: string;
  fold: FoldType;
  executionState: ExecState;
  isFlipped: boolean;
  metrics: {
    cpuPercent?: number;
    latencyMs?: number;
    activityCount?: number;
    indicatorsFound?: number;
  };
  commands: {
    incantation: string;   // The command prompt run
    stdoutTail: string[];   // Latest execution logs
  };
  visuals: {
    rotateX: number;       // Dynamic mouse-tilt X
    rotateY: number;       // Dynamic mouse-tilt Y
    glowColor: string;     // HSL visual pulse accent
  };
}

export interface AtelierNode {
  id: string;
  type: 'tarotCard';
  position: { x: number; y: number };
  data: TarotCardData;
}

export interface AtelierEdge {
  id: string;
  source: string;
  target: string;
  animated: boolean;
  style?: Record<string, any>;
}
