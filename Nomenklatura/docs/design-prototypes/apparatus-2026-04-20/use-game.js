// use-game.js — shared game state hook for all three screen variants.
// Provides: scenario, stats, phase, selectOption, nextTurn, reset.

const { useState, useEffect: _ue, useRef: _ur } = React;

function useGame() {
  const [turnIdx, setTurnIdx] = useState(() => {
    const v = Number(localStorage.getItem('apparatus.turn') || 0);
    return Math.min(Math.max(0, v), SCENARIOS.length - 1);
  });
  const [phase, setPhase] = useState('briefing'); // briefing | outcome | verdict
  const [stats, setStats] = useState(() => {
    try {
      const s = JSON.parse(localStorage.getItem('apparatus.stats') || 'null');
      return s && typeof s === 'object' ? s : { ...INITIAL_STATS };
    } catch { return { ...INITIAL_STATS }; }
  });
  const [prevStats, setPrevStats] = useState({ ...stats });
  const [selectedOpt, setSelectedOpt] = useState(null);
  const [hoveredChar, setHoveredChar] = useState(null);

  _ue(() => { localStorage.setItem('apparatus.turn', String(turnIdx)); }, [turnIdx]);
  _ue(() => { localStorage.setItem('apparatus.stats', JSON.stringify(stats)); }, [stats]);

  const scenario = SCENARIOS[turnIdx];
  const fromCharacter = CHARACTERS[scenario.from];

  function selectOption(opt) {
    if (phase !== 'briefing') return;
    setPrevStats({ ...stats });
    setStats(s => {
      const next = { ...s };
      for (const k of Object.keys(opt.effects)) {
        next[k] = Math.max(0, Math.min(100, (s[k] || 0) + opt.effects[k]));
      }
      return next;
    });
    setSelectedOpt(opt);
    setPhase('outcome');
  }

  function nextTurn() {
    if (turnIdx + 1 >= SCENARIOS.length) {
      setPhase('verdict');
      return;
    }
    setTurnIdx(i => i + 1);
    setSelectedOpt(null);
    setPhase('briefing');
  }

  function reset() {
    setStats({ ...INITIAL_STATS });
    setPrevStats({ ...INITIAL_STATS });
    setTurnIdx(0);
    setSelectedOpt(null);
    setPhase('briefing');
  }

  const delta = (k) => selectedOpt ? (stats[k] - prevStats[k]) : 0;

  return {
    turnIdx, phase, stats, prevStats, selectedOpt, hoveredChar,
    scenario, fromCharacter,
    setHoveredChar, selectOption, nextTurn, reset, delta,
  };
}

Object.assign(window, { useGame });
