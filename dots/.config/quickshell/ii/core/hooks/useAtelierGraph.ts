// core/hooks/useAtelierGraph.ts
// Sun iN Moon (SiM) — Atelier WarRoom React Flow management hook

import { useState, useCallback } from 'react';
import { Node, Edge, useNodesState, useEdgesState } from '@xyflow/react';
import { TarotCardData, FoldType } from '../types/tarot';

export function useAtelierGraph() {
  const [nodes, setNodes, onNodesChange] = useNodesState<Node<TarotCardData>>([]);
  const [edges, setEdges, onEdgesChange] = useEdgesState<Edge>([]);

  // Insert a new Tarot Node dynamically on command execution
  const incantNode = useCallback((
    id: string,
    label: string,
    fold: FoldType,
    incantation: string,
    parentId?: string
  ) => {
    const newNode: Node<TarotCardData> = {
      id,
      type: 'tarotCard',
      position: {
        x: parentId ? Math.random() * 200 - 100 : 250,
        y: parentId ? Math.random() * 200 + 150 : 100,
      },
      data: {
        id,
        label,
        fold,
        executionState: 'incanting',
        isFlipped: false,
        metrics: { activityCount: 0, indicatorsFound: 0 },
        commands: { incantation, stdoutTail: [] },
        visuals: { rotateX: 0, rotateY: 0, glowColor: 'var(--color-pulse)' }
      }
    };

    setNodes((nds) => [...nds, newNode]);

    if (parentId) {
      const newEdge: Edge = {
        id: `e-${parentId}-${id}`,
        source: parentId,
        target: id,
        animated: true,
        style: { stroke: 'var(--stroke-iridescent)', strokeWidth: 2 }
      };
      setEdges((eds) => [...eds, newEdge]);
    }
  }, [setNodes, setEdges]);

  // Handle Tarot card flip state
  const flipCard = useCallback((nodeId: string) => {
    setNodes((nds) =>
      nds.map((n) => {
        if (n.id === nodeId) {
          return {
            ...n,
            data: { ...n.data, isFlipped: !n.data.isFlipped }
          };
        }
        return n;
      })
    );
  }, [setNodes]);

  return {
    nodes,
    edges,
    incantNode,
    flipCard,
    onNodesChange,
    onEdgesChange,
    setNodes
  };
}
