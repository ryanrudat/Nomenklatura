// desk-screen.jsx — The Desk: main gameplay view
// Briefing paper + stance options + outcome. Themed via THEMES object.
// Handles: option selection, outcome animation, stat meter animation, next turn, dossier hover

const { useState, useEffect, useRef } = React;

// ─── Original iconography: 5-point star with apparatus gear ───
function ApparatusStar({ size = 24, color = '#8b1818', style = {} }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" style={style}>
      <polygon
        points="12,2 14.6,8.6 21.8,9 16.2,13.6 18.2,20.6 12,16.6 5.8,20.6 7.8,13.6 2.2,9 9.4,8.6"
        fill={color}
      />
      <circle cx="12" cy="12" r="2.2" fill="none" stroke={color === '#fff' ? 'rgba(0,0,0,0.3)' : 'rgba(255,255,255,0.25)'} strokeWidth="1" />
    </svg>
  );
}

// ─── Rubber stamp (themed, rotated, semi-transparent) ───
function Stamp({ text, color, rotate = -12, size = 1, style = {} }) {
  return (
    <div style={{
      display: 'inline-block',
      padding: `${6 * size}px ${14 * size}px`,
      border: `${2.5 * size}px solid ${color}`,
      color: color,
      fontFamily: '"Oswald", "Arial Black", sans-serif',
      fontWeight: 800,
      fontSize: 14 * size,
      letterSpacing: 2,
      transform: `rotate(${rotate}deg)`,
      opacity: 0.78,
      textTransform: 'uppercase',
      whiteSpace: 'nowrap',
      boxShadow: `inset 0 0 0 1px ${color}33`,
      ...style,
    }}>{text}</div>
  );
}

// ─── Paperclip (SVG) ───
function Paperclip({ color = '#4a4a4a', style = {} }) {
  return (
    <svg width="28" height="70" viewBox="0 0 28 70" style={style}>
      <path d="M14 4 C20 4, 24 8, 24 14 L24 52 C24 58, 20 62, 14 62 C8 62, 4 58, 4 52 L4 18 C4 14, 6 12, 10 12 C14 12, 16 14, 16 18 L16 48"
        fill="none" stroke={color} strokeWidth="2.2" strokeLinecap="round" opacity="0.85" />
    </svg>
  );
}

// ─── Red wax seal ───
function WaxSeal({ size = 52, color = '#8b1818' }) {
  return (
    <div style={{
      width: size, height: size, borderRadius: '50%',
      background: `radial-gradient(circle at 35% 30%, ${color}ee, ${color}cc 50%, #5a0a0a 100%)`,
      display: 'flex', alignItems: 'center', justifyContent: 'center',
      boxShadow: '0 2px 4px rgba(0,0,0,0.4), inset 0 -3px 6px rgba(0,0,0,0.3)',
      position: 'relative',
    }}>
      <ApparatusStar size={size * 0.55} color="rgba(255,220,200,0.7)" />
    </div>
  );
}

// ─── Stat meter: animated bar ───
function StatMeter({ label, icon, value, delta, theme, showDelta }) {
  const [display, setDisplay] = useState(value - (delta || 0));
  useEffect(() => {
    if (!showDelta) { setDisplay(value); return; }
    const start = display;
    const end = value;
    const t0 = performance.now();
    const dur = 900;
    let raf;
    const step = (t) => {
      const p = Math.min(1, (t - t0) / dur);
      const eased = 1 - Math.pow(1 - p, 3);
      setDisplay(Math.round(start + (end - start) * eased));
      if (p < 1) raf = requestAnimationFrame(step);
    };
    raf = requestAnimationFrame(step);
    return () => cancelAnimationFrame(raf);
  }, [value, showDelta]);

  const pct = Math.max(0, Math.min(100, display));
  const deltaVisible = showDelta && delta && delta !== 0;

  return (
    <div style={{ marginBottom: 10 }}>
      <div style={{
        display: 'flex', justifyContent: 'space-between',
        fontFamily: theme.mono, fontSize: 10,
        color: theme.inkSoft, letterSpacing: 1.2,
        textTransform: 'uppercase', marginBottom: 4,
      }}>
        <span>{icon} {label}</span>
        <span style={{ color: theme.ink, fontWeight: 600 }}>
          {display}
          {deltaVisible && (
            <span style={{
              marginLeft: 6,
              color: delta > 0 ? '#2a7a3a' : theme.accent,
              fontWeight: 700,
            }}>{delta > 0 ? '+' : ''}{delta}</span>
          )}
        </span>
      </div>
      <div style={{
        height: 6, background: theme.ruleSoft,
        border: `0.5px solid ${theme.rule}`,
        position: 'relative', overflow: 'hidden',
      }}>
        <div style={{
          width: `${pct}%`, height: '100%',
          background: theme.ink,
          transition: 'width 0.9s cubic-bezier(0.2, 0.8, 0.2, 1)',
        }} />
        {/* Tick marks */}
        {[25, 50, 75].map(p => (
          <div key={p} style={{
            position: 'absolute', left: `${p}%`, top: 0, bottom: 0,
            width: 0.5, background: theme.paper, opacity: 0.8,
          }} />
        ))}
      </div>
    </div>
  );
}

// ─── Character chip with hover dossier ───
function CharacterChip({ character, theme, onHover }) {
  const [hover, setHover] = useState(false);
  return (
    <div
      onMouseEnter={() => { setHover(true); onHover && onHover(character); }}
      onMouseLeave={() => { setHover(false); onHover && onHover(null); }}
      onClick={() => { setHover(h => !h); onHover && onHover(hover ? null : character); }}
      style={{
        display: 'inline-flex', alignItems: 'center', gap: 8,
        padding: '4px 10px 4px 4px',
        background: theme.paperDeep,
        border: `0.5px solid ${theme.rule}`,
        borderRadius: theme.cardRadius,
        cursor: 'pointer',
        position: 'relative',
        fontFamily: theme.body,
      }}
    >
      <div style={{
        width: 28, height: 28, borderRadius: theme.cardRadius,
        background: character.portrait,
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        color: '#efe4c9', fontFamily: theme.display,
        fontSize: 12, fontWeight: 700, letterSpacing: 0.5,
      }}>{character.initials}</div>
      <div>
        <div style={{ fontSize: 11, color: theme.ink, fontWeight: 600, lineHeight: 1.2 }}>{character.name}</div>
        <div style={{ fontSize: 9, color: theme.inkFaint, fontFamily: theme.mono, letterSpacing: 0.5, textTransform: 'uppercase' }}>{character.role}</div>
      </div>
    </div>
  );
}

// ─── Dossier hover card ───
function DossierCard({ character, theme, style = {} }) {
  if (!character) return null;
  return (
    <div style={{
      position: 'absolute',
      background: theme.paper,
      border: `1px solid ${theme.rule}`,
      borderLeft: `3px solid ${theme.accent}`,
      borderRadius: theme.cardRadius,
      padding: 12,
      fontFamily: theme.body,
      color: theme.ink,
      boxShadow: theme.dark
        ? '0 8px 24px rgba(0,0,0,0.6), 0 0 0 1px rgba(212,200,168,0.1)'
        : '0 8px 24px rgba(42, 34, 22, 0.25)',
      zIndex: 100,
      width: 260,
      ...style,
    }}>
      <div style={{
        fontFamily: theme.mono, fontSize: 9, letterSpacing: 1.5,
        color: theme.accent, textTransform: 'uppercase', marginBottom: 6,
      }}>DOSSIER — {character.role.toUpperCase()}</div>
      <div style={{ display: 'flex', gap: 10, marginBottom: 10 }}>
        <div style={{
          width: 44, height: 52,
          background: character.portrait,
          display: 'flex', alignItems: 'center', justifyContent: 'center',
          color: '#efe4c9', fontFamily: theme.display,
          fontSize: 16, fontWeight: 700, flexShrink: 0,
        }}>{character.initials}</div>
        <div style={{ flex: 1 }}>
          <div style={{ fontSize: 13, fontWeight: 700, lineHeight: 1.2 }}>{character.name}</div>
          <div style={{ fontSize: 10, color: theme.inkSoft, fontStyle: 'italic', marginTop: 2 }}>{character.rank}</div>
          <div style={{
            marginTop: 6, fontSize: 9, fontFamily: theme.mono,
            color: theme.inkSoft, letterSpacing: 1, textTransform: 'uppercase',
          }}>Loyalty {character.loyalty}%</div>
          <div style={{
            height: 3, background: theme.ruleSoft, marginTop: 2,
          }}>
            <div style={{ width: `${character.loyalty}%`, height: '100%', background: theme.accent }} />
          </div>
        </div>
      </div>
      <ul style={{ margin: 0, padding: 0, listStyle: 'none' }}>
        {character.dossier.map((line, i) => (
          <li key={i} style={{
            fontSize: 11, lineHeight: 1.4, marginBottom: 4,
            paddingLeft: 10, position: 'relative',
          }}>
            <span style={{ position: 'absolute', left: 0, color: theme.accent }}>·</span>
            {line}
          </li>
        ))}
      </ul>
    </div>
  );
}

// ─── Main Desk Screen ───
function DeskScreen({ theme, onThemeCycle }) {
  const [turnIdx, setTurnIdx] = useState(() => {
    const saved = Number(localStorage.getItem('nomenklatura_turn') || '0');
    return Math.max(0, Math.min(SCENARIOS.length - 1, saved));
  });
  const [phase, setPhase] = useState('briefing'); // briefing | outcome
  const [selectedOpt, setSelectedOpt] = useState(null);
  const [stats, setStats] = useState(() => {
    try {
      const s = JSON.parse(localStorage.getItem('nomenklatura_stats') || 'null');
      return s || INITIAL_STATS;
    } catch { return INITIAL_STATS; }
  });
  const [prevStats, setPrevStats] = useState(stats);
  const [hoveredChar, setHoveredChar] = useState(null);
  const [tabView, setTabView] = useState('briefing'); // briefing | actors | ledger
  const [swipeDX, setSwipeDX] = useState(0);
  const touchRef = useRef({ x: 0, active: false });

  useEffect(() => {
    localStorage.setItem('nomenklatura_turn', String(turnIdx));
  }, [turnIdx]);
  useEffect(() => {
    localStorage.setItem('nomenklatura_stats', JSON.stringify(stats));
  }, [stats]);

  const scenario = SCENARIOS[turnIdx];
  const fromCharacter = CHARACTERS[scenario.from];

  const selectOption = (opt) => {
    setPrevStats({ ...stats });
    const next = { ...stats };
    Object.entries(opt.effects).forEach(([k, v]) => {
      if (next[k] !== undefined) next[k] = Math.max(0, Math.min(100, next[k] + v));
    });
    setStats(next);
    setSelectedOpt(opt);
    setPhase('outcome');
  };

  const nextTurn = () => {
    const next = turnIdx + 1;
    if (next >= SCENARIOS.length) {
      // Loop back for demo
      setTurnIdx(0);
    } else {
      setTurnIdx(next);
    }
    setPhase('briefing');
    setSelectedOpt(null);
    setTabView('briefing');
  };

  const reset = () => {
    setTurnIdx(0);
    setPhase('briefing');
    setSelectedOpt(null);
    setStats(INITIAL_STATS);
    setPrevStats(INITIAL_STATS);
    setTabView('briefing');
    localStorage.removeItem('nomenklatura_turn');
    localStorage.removeItem('nomenklatura_stats');
  };

  // Swipe to advance (only in outcome phase)
  const onTouchStart = (e) => {
    touchRef.current = { x: e.touches[0].clientX, active: true };
  };
  const onTouchMove = (e) => {
    if (!touchRef.current.active) return;
    setSwipeDX(e.touches[0].clientX - touchRef.current.x);
  };
  const onTouchEnd = () => {
    if (swipeDX < -60 && phase === 'outcome') nextTurn();
    setSwipeDX(0);
    touchRef.current.active = false;
  };

  const delta = (k) => selectedOpt ? (stats[k] - prevStats[k]) : 0;

  return (
    <div
      style={{
        height: '100%', width: '100%',
        background: theme.bg,
        color: theme.ink,
        fontFamily: theme.body,
        position: 'relative',
        overflow: 'hidden',
        display: 'flex', flexDirection: 'column',
      }}
      onTouchStart={onTouchStart}
      onTouchMove={onTouchMove}
      onTouchEnd={onTouchEnd}
    >
      {/* Paper noise overlay */}
      {theme.paperNoise && <PaperTexture theme={theme} />}

      {/* Top bureau header (replaces iOS nav) */}
      <BureauHeader theme={theme} scenario={scenario} turnIdx={turnIdx} onReset={reset} />

      {/* Tab bar */}
      <TabBar theme={theme} active={tabView} onSelect={setTabView} />

      {/* Body */}
      <div style={{
        flex: 1, overflowY: 'auto', overflowX: 'hidden',
        padding: '10px 14px 90px',
        position: 'relative',
        transform: phase === 'outcome' ? `translateX(${swipeDX * 0.4}px)` : 'none',
        transition: touchRef.current.active ? 'none' : 'transform 0.3s ease',
      }}>
        {tabView === 'briefing' && phase === 'briefing' && (
          <BriefingView
            theme={theme} scenario={scenario}
            fromCharacter={fromCharacter}
            onSelect={selectOption}
            onHover={setHoveredChar}
          />
        )}
        {tabView === 'briefing' && phase === 'outcome' && (
          <OutcomeView
            theme={theme} scenario={scenario}
            option={selectedOpt}
            stats={stats} delta={delta}
            onNext={nextTurn}
          />
        )}
        {tabView === 'actors' && (
          <ActorsView theme={theme} stats={stats} />
        )}
        {tabView === 'ledger' && (
          <LedgerView theme={theme} stats={stats} prevStats={prevStats} showDelta={phase === 'outcome'} />
        )}
      </div>

      {/* Hover dossier */}
      {hoveredChar && (
        <DossierCard
          character={hoveredChar}
          theme={theme}
          style={{ bottom: 80, left: 14, right: 14, width: 'auto' }}
        />
      )}

      {/* Bottom status strip with theme cycle */}
      <BottomStrip theme={theme} onThemeCycle={onThemeCycle} turnIdx={turnIdx} phase={phase} />
    </div>
  );
}

// ─── Bureau header ───
function BureauHeader({ theme, scenario, turnIdx, onReset }) {
  return (
    <div style={{
      paddingTop: 54, // status bar
      paddingBottom: 8,
      borderBottom: `1px solid ${theme.rule}`,
      background: theme.paperDeep,
      position: 'relative',
    }}>
      <div style={{
        padding: '0 14px',
        display: 'flex', justifyContent: 'space-between', alignItems: 'flex-end',
      }}>
        <div>
          <div style={{
            fontFamily: theme.mono, fontSize: 9, letterSpacing: 2,
            color: theme.inkFaint, textTransform: 'uppercase',
          }}>PSRA · {scenario.classification}</div>
          <div style={{
            fontFamily: theme.display,
            fontSize: theme.key === 'red' ? 22 : 18,
            fontWeight: theme.key === 'red' ? 500 : 700,
            lineHeight: 1.05, color: theme.ink,
            letterSpacing: theme.key === 'red' ? 0.5 : 0,
            textTransform: theme.key === 'red' ? 'uppercase' : 'none',
            marginTop: 2,
          }}>
            {theme.key === 'red' ? 'THE APPARATUS' : 'The Apparatus'}
          </div>
          <div style={{
            fontFamily: theme.mono, fontSize: 9, color: theme.inkSoft,
            letterSpacing: 1, marginTop: 2,
          }}>
            TURN {String(turnIdx + 1).padStart(2, '0')} / {String(SCENARIOS.length).padStart(2, '0')} · {scenario.date.toUpperCase()}
          </div>
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
          <ApparatusStar size={28} color={theme.star} />
          <button onClick={onReset} style={{
            background: 'transparent',
            border: `1px solid ${theme.rule}`,
            color: theme.inkSoft,
            padding: '3px 8px',
            fontFamily: theme.mono,
            fontSize: 8,
            letterSpacing: 1,
            borderRadius: theme.cardRadius,
            cursor: 'pointer',
            textTransform: 'uppercase',
          }}>Reset</button>
        </div>
      </div>
    </div>
  );
}

// ─── Tabs ───
function TabBar({ theme, active, onSelect }) {
  const tabs = [
    { id: 'briefing', label: 'Desk' },
    { id: 'actors', label: 'Dossier' },
    { id: 'ledger', label: 'Ledger' },
  ];
  return (
    <div style={{
      display: 'flex',
      borderBottom: `1px solid ${theme.rule}`,
      background: theme.paperDeep,
    }}>
      {tabs.map(t => (
        <button key={t.id} onClick={() => onSelect(t.id)} style={{
          flex: 1, padding: '10px 0',
          background: active === t.id ? theme.paper : 'transparent',
          border: 'none',
          borderBottom: active === t.id ? `2px solid ${theme.accent}` : '2px solid transparent',
          color: active === t.id ? theme.ink : theme.inkFaint,
          fontFamily: theme.mono,
          fontSize: 10,
          letterSpacing: 2,
          textTransform: 'uppercase',
          cursor: 'pointer',
          fontWeight: active === t.id ? 600 : 400,
        }}>{t.label}</button>
      ))}
    </div>
  );
}

// ─── Briefing: document card + option cards ───
function BriefingView({ theme, scenario, fromCharacter, onSelect, onHover }) {
  return (
    <div style={{ position: 'relative' }}>
      {/* Paperclip decoration */}
      {theme.showPaperclip && (
        <div style={{
          position: 'absolute', top: -6, right: 28, zIndex: 5,
          transform: 'rotate(8deg)',
        }}>
          <Paperclip color="#3a3a3a" />
        </div>
      )}

      {/* Document header */}
      <div style={{
        background: theme.paper,
        border: `1px solid ${theme.rule}`,
        borderRadius: theme.cardRadius,
        padding: '16px 16px 14px',
        position: 'relative',
        boxShadow: theme.dark ? 'none' : '0 1px 2px rgba(42,34,22,0.08)',
      }}>
        {/* Doc number strip */}
        <div style={{
          display: 'flex', justifyContent: 'space-between',
          fontFamily: theme.mono, fontSize: 9,
          color: theme.inkFaint, letterSpacing: 1.5,
          textTransform: 'uppercase',
          borderBottom: `0.5px solid ${theme.rule}`,
          paddingBottom: 6, marginBottom: 10,
        }}>
          <span>{scenario.docNumber}</span>
          <span>{scenario.bureau.toUpperCase()}</span>
        </div>

        {/* Classified stamp */}
        {theme.showStamps && (
          <div style={{
            position: 'absolute', top: 34, right: 12,
            pointerEvents: 'none',
          }}>
            <Stamp text={scenario.classification} color={theme.accent} rotate={-6} size={0.85} />
          </div>
        )}

        {/* Censored simulation */}
        {theme.censored && (
          <div style={{
            display: 'flex', gap: 4, marginBottom: 10,
          }}>
            <span style={{ background: theme.ink, color: theme.ink, fontFamily: theme.mono, fontSize: 10 }}>████████████</span>
            <span style={{ background: theme.ink, color: theme.ink, fontFamily: theme.mono, fontSize: 10 }}>█████</span>
          </div>
        )}

        {/* Title */}
        <div style={{
          fontFamily: theme.display,
          fontSize: theme.key === 'red' ? 22 : 19,
          fontWeight: theme.key === 'red' ? 600 : 700,
          lineHeight: 1.15,
          color: theme.ink,
          textTransform: theme.key === 'red' ? 'uppercase' : 'none',
          letterSpacing: theme.key === 'red' ? 0.3 : 0,
          marginBottom: 12,
          maxWidth: '85%',
        }}>{scenario.title}</div>

        {/* From (character chip) */}
        <div style={{ marginBottom: 12 }}>
          <div style={{
            fontFamily: theme.mono, fontSize: 8, letterSpacing: 2,
            color: theme.inkFaint, textTransform: 'uppercase', marginBottom: 4,
          }}>TRANSMITTED FROM</div>
          <CharacterChip character={fromCharacter} theme={theme} onHover={onHover} />
        </div>

        {/* Briefing body */}
        <div style={{
          fontFamily: theme.carbonCopy ? theme.mono : theme.body,
          fontSize: theme.carbonCopy ? 12 : 14,
          lineHeight: 1.55,
          color: theme.ink,
          textWrap: 'pretty',
        }}>
          {scenario.briefing.map((p, i) => (
            <p key={i} style={{
              margin: i === 0 ? '0 0 8px' : '0 0 8px',
              fontStyle: i === 0 && !theme.carbonCopy ? 'italic' : 'normal',
              color: i === 0 ? theme.inkSoft : theme.ink,
            }}>{p}</p>
          ))}
        </div>

        {/* Signature */}
        <div style={{
          marginTop: 14, paddingTop: 10,
          borderTop: `0.5px solid ${theme.rule}`,
          display: 'flex', justifyContent: 'space-between', alignItems: 'center',
        }}>
          <div style={{
            fontFamily: theme.display,
            fontStyle: 'italic',
            fontSize: 15,
            color: theme.inkSoft,
          }}>{fromCharacter.name}</div>
          {theme.showWax && <WaxSeal size={38} color={theme.accent} />}
        </div>
      </div>

      {/* Options prompt */}
      <div style={{
        marginTop: 18, marginBottom: 10,
        display: 'flex', alignItems: 'center', gap: 8,
      }}>
        <div style={{ flex: 1, height: 1, background: theme.rule }} />
        <div style={{
          fontFamily: theme.mono, fontSize: 9, letterSpacing: 2.5,
          color: theme.inkSoft, textTransform: 'uppercase',
        }}>Your Directive</div>
        <div style={{ flex: 1, height: 1, background: theme.rule }} />
      </div>

      {/* Option cards */}
      <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
        {scenario.options.map((opt, i) => (
          <OptionCard key={opt.id} option={opt} theme={theme} index={i} onSelect={onSelect} />
        ))}
      </div>
    </div>
  );
}

// ─── Option card ───
function OptionCard({ option, theme, index, onSelect }) {
  const [press, setPress] = useState(false);
  return (
    <button
      onMouseDown={() => setPress(true)}
      onMouseUp={() => setPress(false)}
      onMouseLeave={() => setPress(false)}
      onClick={() => onSelect(option)}
      style={{
        textAlign: 'left',
        background: theme.paper,
        border: `1px solid ${theme.rule}`,
        borderLeft: `3px solid ${option.stanceColor}`,
        borderRadius: theme.cardRadius,
        padding: '12px 14px',
        cursor: 'pointer',
        fontFamily: theme.body,
        color: theme.ink,
        boxShadow: press
          ? 'inset 0 2px 6px rgba(0,0,0,0.08)'
          : (theme.dark ? 'none' : '0 1px 2px rgba(42,34,22,0.06)'),
        transform: press ? 'translateY(1px)' : 'none',
        transition: 'all 0.1s ease',
        position: 'relative',
      }}
    >
      <div style={{
        display: 'flex', justifyContent: 'space-between', alignItems: 'center',
        marginBottom: 4,
      }}>
        <div style={{
          fontFamily: theme.mono, fontSize: 9,
          color: option.stanceColor, letterSpacing: 2,
          textTransform: 'uppercase', fontWeight: 700,
        }}>
          {String(index + 1).padStart(2, '0')} · {option.stance}
        </div>
        <div style={{
          fontFamily: theme.mono, fontSize: 10,
          color: theme.inkFaint, letterSpacing: 0.5,
        }}>→</div>
      </div>
      <div style={{
        fontFamily: theme.display,
        fontSize: theme.key === 'red' ? 16 : 15,
        fontWeight: theme.key === 'red' ? 500 : 600,
        lineHeight: 1.25, marginBottom: 3,
        color: theme.ink,
        textTransform: theme.key === 'red' ? 'uppercase' : 'none',
        letterSpacing: theme.key === 'red' ? 0.2 : 0,
      }}>{option.label}</div>
      <div style={{
        fontSize: 12, lineHeight: 1.4,
        color: theme.inkSoft, fontStyle: theme.carbonCopy ? 'normal' : 'italic',
        fontFamily: theme.carbonCopy ? theme.mono : theme.body,
      }}>{option.body}</div>
    </button>
  );
}

// ─── Outcome view ───
function OutcomeView({ theme, scenario, option, stats, delta, onNext }) {
  const [stage, setStage] = useState(0); // 0: stamp appear, 1: text, 2: stats
  useEffect(() => {
    const t1 = setTimeout(() => setStage(1), 300);
    const t2 = setTimeout(() => setStage(2), 800);
    return () => { clearTimeout(t1); clearTimeout(t2); };
  }, []);

  return (
    <div>
      {/* Stamp overlay */}
      <div style={{
        background: theme.paper,
        border: `1px solid ${theme.rule}`,
        borderLeft: `3px solid ${option.stanceColor}`,
        borderRadius: theme.cardRadius,
        padding: '16px',
        position: 'relative',
        minHeight: 180,
      }}>
        <div style={{
          position: 'absolute', top: 10, right: 10,
          opacity: stage >= 0 ? 1 : 0,
          transform: stage >= 0 ? 'scale(1)' : 'scale(1.8)',
          transition: 'all 0.4s cubic-bezier(0.2, 0.9, 0.3, 1.2)',
        }}>
          <Stamp text={option.stamp} color={theme.accent} rotate={-8} size={1} />
        </div>

        <div style={{
          fontFamily: theme.mono, fontSize: 9, letterSpacing: 2,
          color: theme.inkFaint, textTransform: 'uppercase', marginBottom: 6,
        }}>OUTCOME · {scenario.docNumber}</div>

        <div style={{
          fontFamily: theme.display,
          fontSize: theme.key === 'red' ? 22 : 20,
          fontWeight: theme.key === 'red' ? 500 : 700,
          lineHeight: 1.15,
          textTransform: theme.key === 'red' ? 'uppercase' : 'none',
          letterSpacing: theme.key === 'red' ? 0.3 : 0,
          marginBottom: 10,
          maxWidth: '75%',
          opacity: stage >= 1 ? 1 : 0,
          transform: stage >= 1 ? 'translateY(0)' : 'translateY(6px)',
          transition: 'all 0.4s ease',
        }}>{option.outcomeTitle}</div>

        <div style={{
          fontSize: 13, lineHeight: 1.55,
          color: theme.ink,
          textWrap: 'pretty',
          fontFamily: theme.carbonCopy ? theme.mono : theme.body,
          opacity: stage >= 1 ? 1 : 0,
          transform: stage >= 1 ? 'translateY(0)' : 'translateY(6px)',
          transition: 'all 0.5s ease 0.1s',
        }}>{option.outcomeBody}</div>
      </div>

      {/* Stat changes */}
      <div style={{
        marginTop: 14,
        background: theme.paper,
        border: `1px solid ${theme.rule}`,
        borderRadius: theme.cardRadius,
        padding: '12px 14px',
        opacity: stage >= 2 ? 1 : 0,
        transform: stage >= 2 ? 'translateY(0)' : 'translateY(10px)',
        transition: 'all 0.5s ease',
      }}>
        <div style={{
          fontFamily: theme.mono, fontSize: 9, letterSpacing: 2,
          color: theme.inkFaint, textTransform: 'uppercase', marginBottom: 10,
        }}>STATE LEDGER · REVISED</div>
        {Object.entries(STAT_META).map(([k, m]) => (
          <StatMeter
            key={k}
            label={m.label}
            icon={m.icon}
            value={stats[k]}
            delta={delta(k)}
            theme={theme}
            showDelta={stage >= 2}
          />
        ))}
      </div>

      {/* Next turn button */}
      <button onClick={onNext} style={{
        marginTop: 18,
        width: '100%',
        background: theme.accent,
        color: '#fff',
        border: 'none',
        borderRadius: theme.cardRadius,
        padding: '14px',
        fontFamily: theme.mono,
        fontSize: 11,
        letterSpacing: 3,
        textTransform: 'uppercase',
        fontWeight: 700,
        cursor: 'pointer',
        boxShadow: theme.dark ? '0 0 0 1px rgba(199,40,40,0.3)' : '0 2px 0 rgba(0,0,0,0.15)',
      }}>
        {scenario.turn < SCENARIOS.length ? 'Proceed to Next Directive' : 'Begin Anew'} →
      </button>

      <div style={{
        marginTop: 10, textAlign: 'center',
        fontFamily: theme.mono, fontSize: 9,
        color: theme.inkFaint, letterSpacing: 1.5,
      }}>swipe left to advance</div>
    </div>
  );
}

// ─── Actors view (all characters) ───
function ActorsView({ theme }) {
  return (
    <div>
      <div style={{
        fontFamily: theme.mono, fontSize: 10, letterSpacing: 2,
        color: theme.inkSoft, textTransform: 'uppercase', marginBottom: 10,
      }}>INNER CIRCLE · MARCH 1952</div>
      {Object.values(CHARACTERS).map(char => (
        <div key={char.id} style={{
          background: theme.paper,
          border: `1px solid ${theme.rule}`,
          borderLeft: `3px solid ${theme.accent}`,
          borderRadius: theme.cardRadius,
          padding: 12, marginBottom: 10,
          display: 'flex', gap: 12,
        }}>
          <div style={{
            width: 52, height: 62, flexShrink: 0,
            background: char.portrait,
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            color: '#efe4c9', fontFamily: theme.display,
            fontSize: 20, fontWeight: 700,
          }}>{char.initials}</div>
          <div style={{ flex: 1, minWidth: 0 }}>
            <div style={{
              fontFamily: theme.display,
              fontSize: theme.key === 'red' ? 16 : 15, fontWeight: 700,
              color: theme.ink, lineHeight: 1.15,
              textTransform: theme.key === 'red' ? 'uppercase' : 'none',
            }}>{char.name}</div>
            <div style={{ fontSize: 11, fontStyle: 'italic', color: theme.inkSoft, marginTop: 1 }}>{char.rank}</div>
            <div style={{
              fontFamily: theme.mono, fontSize: 8, letterSpacing: 1.5,
              color: char.relation === 'rival' ? theme.accent : theme.inkFaint,
              textTransform: 'uppercase', marginTop: 4,
            }}>{char.role} · LOYALTY {char.loyalty}%</div>
            <div style={{
              height: 3, background: theme.ruleSoft, marginTop: 3,
            }}>
              <div style={{ width: `${char.loyalty}%`, height: '100%', background: char.relation === 'rival' ? theme.accent : theme.ink }} />
            </div>
            <div style={{
              fontSize: 11, color: theme.inkSoft, marginTop: 8,
              fontStyle: 'italic', lineHeight: 1.4,
            }}>{char.dossier[0]}</div>
          </div>
        </div>
      ))}
    </div>
  );
}

// ─── Ledger view ───
function LedgerView({ theme, stats, prevStats, showDelta }) {
  return (
    <div>
      <div style={{
        fontFamily: theme.mono, fontSize: 10, letterSpacing: 2,
        color: theme.inkSoft, textTransform: 'uppercase', marginBottom: 10,
      }}>STATE OF THE REPUBLIC</div>
      <div style={{
        background: theme.paper,
        border: `1px solid ${theme.rule}`,
        borderRadius: theme.cardRadius,
        padding: 14, marginBottom: 14,
      }}>
        {Object.entries(STAT_META).map(([k, m]) => (
          <StatMeter
            key={k}
            label={m.label}
            icon={m.icon}
            value={stats[k]}
            delta={showDelta ? stats[k] - prevStats[k] : 0}
            theme={theme}
            showDelta={showDelta}
          />
        ))}
      </div>

      {/* Map placeholder */}
      <div style={{
        fontFamily: theme.mono, fontSize: 10, letterSpacing: 2,
        color: theme.inkSoft, textTransform: 'uppercase', marginBottom: 8,
      }}>TERRITORY · THE CONTINENT</div>
      <div style={{
        aspectRatio: '1 / 1.1',
        background: theme.paperDeep,
        border: `1px solid ${theme.rule}`,
        borderRadius: theme.cardRadius,
        position: 'relative',
        overflow: 'hidden',
      }}>
        <MapPlaceholder theme={theme} />
      </div>
    </div>
  );
}

// ─── Simple map placeholder using SVG ───
function MapPlaceholder({ theme }) {
  // Colored nation blobs roughly following the MapDesign layout — simplified
  return (
    <svg viewBox="0 0 100 110" style={{ width: '100%', height: '100%', display: 'block' }}>
      {/* Ocean */}
      <rect width="100" height="110" fill={theme.dark ? '#1a2a3a' : '#9ab2c0'} opacity="0.5" />
      {/* PSRA (homeland) */}
      <polygon points="30,15 70,10 80,18 82,35 78,50 68,55 50,56 40,50 32,40 28,25"
        fill={theme.accent} opacity="0.85" stroke={theme.ink} strokeWidth="0.5" />
      {/* Zimograd (rival) */}
      <polygon points="12,2 50,2 50,10 30,18 20,10" fill={theme.dark ? '#8a6a3a' : '#b49060'} stroke={theme.ink} strokeWidth="0.4" />
      {/* Valdoria (ally) */}
      <polygon points="50,2 82,2 82,15 70,12 50,10" fill={theme.dark ? '#8a3a3a' : '#b85c5c'} stroke={theme.ink} strokeWidth="0.4" />
      {/* Korvath */}
      <polygon points="12,2 12,50 28,50 28,25 20,10" fill={theme.dark ? '#4a5a78' : '#6e8098'} stroke={theme.ink} strokeWidth="0.4" />
      {/* Brechtland */}
      <polygon points="82,2 92,2 92,55 80,52 78,35 82,15" fill={theme.dark ? '#4a5a78' : '#6e8098'} stroke={theme.ink} strokeWidth="0.4" />
      {/* South */}
      <polygon points="32,60 68,60 72,75 70,95 50,105 32,95 28,78" fill={theme.dark ? '#6a6a5a' : '#9a9a80'} stroke={theme.ink} strokeWidth="0.4" />
      {/* Islands */}
      <ellipse cx="5" cy="40" rx="3" ry="6" fill={theme.dark ? '#4a5a78' : '#6e8098'} />
      <ellipse cx="4" cy="58" rx="2" ry="4" fill={theme.dark ? '#4a5a78' : '#6e8098'} />
      {/* Capital star */}
      <polygon
        points="55,32 56,35 59,35 56.5,37 57.5,40 55,38 52.5,40 53.5,37 51,35 54,35"
        fill={theme.accent2}
        stroke={theme.ink} strokeWidth="0.2"
      />
      {/* Labels */}
      <text x="55" y="28" fill={theme.ink} fontSize="3.5" fontFamily={theme.display} fontWeight="700" textAnchor="middle" letterSpacing="0.3">PSRA</text>
      <text x="30" y="8" fill={theme.ink} fontSize="2" fontFamily={theme.mono} textAnchor="middle">ZIMOGRAD</text>
      <text x="66" y="8" fill={theme.ink} fontSize="2" fontFamily={theme.mono} textAnchor="middle">VALDORIA</text>
      <text x="50" y="82" fill={theme.ink} fontSize="2" fontFamily={theme.mono} textAnchor="middle">CONFEDERATION</text>
      {/* Grid lines */}
      {[25, 50, 75].map(y => <line key={y} x1="0" y1={y * 1.1 / 100 * 100} x2="100" y2={y * 1.1 / 100 * 100} stroke={theme.ink} strokeWidth="0.15" opacity="0.2" strokeDasharray="1 2" />)}
    </svg>
  );
}

// ─── Paper texture overlay (SVG noise) ───
function PaperTexture({ theme }) {
  return (
    <div style={{
      position: 'absolute', inset: 0, pointerEvents: 'none', zIndex: 1,
      opacity: theme.dark ? 0.5 : 0.35,
      backgroundImage: `url("data:image/svg+xml,%3Csvg viewBox='0 0 200 200' xmlns='http://www.w3.org/2000/svg'%3E%3Cfilter id='n'%3E%3CfeTurbulence type='fractalNoise' baseFrequency='0.8' numOctaves='3' stitchTiles='stitch'/%3E%3CfeColorMatrix values='0 0 0 0 0.${theme.dark ? '1' : '4'} 0 0 0 0 0.${theme.dark ? '09' : '35'} 0 0 0 0 0.${theme.dark ? '07' : '25'} 0 0 0 0.5 0'/%3E%3C/filter%3E%3Crect width='100%25' height='100%25' filter='url(%23n)'/%3E%3C/svg%3E")`,
      mixBlendMode: theme.dark ? 'screen' : 'multiply',
    }} />
  );
}

// ─── Bottom strip ───
function BottomStrip({ theme, onThemeCycle, turnIdx, phase }) {
  return (
    <div style={{
      position: 'absolute', bottom: 0, left: 0, right: 0,
      height: 54,
      background: theme.paperDeep,
      borderTop: `1px solid ${theme.rule}`,
      display: 'flex', alignItems: 'center', justifyContent: 'space-between',
      padding: '0 18px 12px',
      zIndex: 40,
      paddingBottom: 20,
    }}>
      <div style={{
        fontFamily: theme.mono, fontSize: 9, letterSpacing: 1.5,
        color: theme.inkFaint, textTransform: 'uppercase',
      }}>
        {phase === 'briefing' ? 'AWAITING DIRECTIVE' : 'DIRECTIVE FILED'}
      </div>
      <button onClick={onThemeCycle} style={{
        background: 'transparent',
        border: `1px solid ${theme.rule}`,
        color: theme.inkSoft,
        padding: '4px 10px',
        fontFamily: theme.mono, fontSize: 9,
        letterSpacing: 1.5,
        borderRadius: theme.cardRadius,
        cursor: 'pointer',
        textTransform: 'uppercase',
        display: 'flex', alignItems: 'center', gap: 6,
      }}>
        <span style={{ width: 8, height: 8, background: theme.accent, display: 'inline-block' }} />
        {theme.name}
      </button>
    </div>
  );
}

Object.assign(window, { DeskScreen });
