// dossier-screen.jsx — PARCHMENT DOSSIER variation
// METAPHOR: a manila file folder on a leather desk blotter. The briefing is a
// typed memo on aged paper with handwritten margin notes, paperclipped photo of
// the sender, wax seal, and three index-card options clipped below.

const { useState: _ds_us, useEffect: _ds_ue, useRef: _ds_ur } = React;

// ── Wax seal ──
function DossierWax({ size = 60, color = '#8b1818' }) {
  const r = size / 2;
  return (
    <svg width={size} height={size} viewBox={`0 0 ${size} ${size}`} style={{ filter: 'drop-shadow(0 2px 3px rgba(0,0,0,0.35))' }}>
      <defs>
        <radialGradient id="waxG" cx="40%" cy="35%">
          <stop offset="0%" stopColor="#c23a3a" />
          <stop offset="55%" stopColor={color} />
          <stop offset="100%" stopColor="#4a0a0a" />
        </radialGradient>
      </defs>
      {/* splatter */}
      <path d={`M ${r} ${r} m -${r*0.85} -${r*0.35} q ${r*0.25} -${r*0.55} ${r*0.9} -${r*0.3} q ${r*0.55} -${r*0.3} ${r*0.9} ${r*0.25} q ${r*0.45} ${r*0.4} ${r*0.05} ${r*0.85} q -${r*0.55} ${r*0.5} -${r*0.95} ${r*0.15} q -${r*0.5} -${r*0.3} -${r*0.85} -${r*0.35} z`} fill="url(#waxG)" />
      {/* star emblem */}
      <polygon points={`${r},${r-r*0.5} ${r+r*0.15},${r-r*0.15} ${r+r*0.5},${r-r*0.15} ${r+r*0.22},${r+r*0.08} ${r+r*0.32},${r+r*0.45} ${r},${r+r*0.22} ${r-r*0.32},${r+r*0.45} ${r-r*0.22},${r+r*0.08} ${r-r*0.5},${r-r*0.15} ${r-r*0.15},${r-r*0.15}`} fill="#2a0808" opacity="0.55" />
    </svg>
  );
}

// ── Typed stamp (rotated diagonally) ──
function DossierStamp({ text, color = '#8b1818', rotate = -7 }) {
  return (
    <div style={{
      display: 'inline-block',
      border: `2.2px solid ${color}`,
      color,
      padding: '4px 12px',
      fontFamily: '"Oswald", sans-serif',
      fontWeight: 800,
      fontSize: 11,
      letterSpacing: 2,
      transform: `rotate(${rotate}deg)`,
      textTransform: 'uppercase',
      opacity: 0.82,
      whiteSpace: 'nowrap',
    }}>{text}</div>
  );
}

// ── Paperclip ──
function DossierPaperclip({ angle = 8, size = 60 }) {
  return (
    <svg width={size * 0.4} height={size} viewBox="0 0 24 60" style={{ transform: `rotate(${angle}deg)`, filter: 'drop-shadow(0 1px 2px rgba(0,0,0,0.4))' }}>
      <path d="M12 3 C17 3 20 6 20 11 L20 44 C20 49 17 52 12 52 C7 52 4 49 4 44 L4 15 C4 12 6 10 9 10 C12 10 14 12 14 15 L14 41" fill="none" stroke="#5a5e6a" strokeWidth="2" strokeLinecap="round" />
      <path d="M12 3 C17 3 20 6 20 11 L20 44 C20 49 17 52 12 52 C7 52 4 49 4 44 L4 15 C4 12 6 10 9 10 C12 10 14 12 14 15 L14 41" fill="none" stroke="#aab0ba" strokeWidth="0.8" strokeLinecap="round" />
    </svg>
  );
}

// ── Tape strip ──
function TapeStrip({ width = 60, angle = -2, style = {} }) {
  return (
    <div style={{
      width, height: 18,
      background: 'linear-gradient(180deg, rgba(240,228,180,0.65), rgba(220,205,150,0.55))',
      border: '1px solid rgba(160,140,90,0.35)',
      transform: `rotate(${angle}deg)`,
      boxShadow: '0 1px 3px rgba(0,0,0,0.18)',
      ...style,
    }} />
  );
}

// ── Character portrait photo (polaroid-ish) ──
function DossierPortrait({ character, size = 68 }) {
  return (
    <div style={{
      width: size, height: size * 1.25,
      background: '#f8f1dd',
      padding: 4,
      boxShadow: '0 2px 5px rgba(0,0,0,0.3), 0 0 0 1px rgba(0,0,0,0.1)',
      position: 'relative',
    }}>
      <div style={{
        width: '100%', height: size,
        background: `linear-gradient(135deg, ${character.portrait}, ${character.portrait}aa)`,
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        position: 'relative',
      }}>
        <div style={{
          fontFamily: '"IM Fell English", serif',
          color: 'rgba(255,255,255,0.92)',
          fontSize: 26, fontWeight: 700,
          letterSpacing: 1,
          textShadow: '0 1px 2px rgba(0,0,0,0.4)',
        }}>{character.initials}</div>
        {/* duotone overlay to look like sepia photo */}
        <div style={{ position:'absolute', inset: 0, background: 'radial-gradient(ellipse at 35% 25%, rgba(255,230,180,0.18), rgba(50,30,10,0.35))', mixBlendMode: 'multiply' }} />
      </div>
      <div style={{
        fontFamily: '"Special Elite", monospace',
        fontSize: 7, letterSpacing: 0.5,
        color: '#4a3a22',
        textAlign: 'center',
        marginTop: 3,
      }}>{character.name.toUpperCase()}</div>
    </div>
  );
}

// ── Desk pad (leather + wood frame) ──
function DeskBlotter({ children, theme }) {
  return (
    <div style={{
      position: 'absolute', inset: 0,
      background: `
        radial-gradient(ellipse at 50% 0%, #8a6a3a 0%, #5a3e1e 70%, #2a1a08 100%)
      `,
    }}>
      {/* Wood grain */}
      <div style={{
        position: 'absolute', inset: 0,
        backgroundImage: `repeating-linear-gradient(87deg, transparent 0, transparent 7px, rgba(30,18,8,0.22) 7px, rgba(30,18,8,0.22) 8px, transparent 8px, transparent 14px, rgba(50,30,12,0.15) 14px, rgba(50,30,12,0.15) 15px)`,
        opacity: 0.55,
      }} />
      {/* Leather blotter */}
      <div style={{
        position: 'absolute',
        top: 60, left: 10, right: 10, bottom: 56,
        background: '#3a2818',
        boxShadow: 'inset 0 0 0 2px #6a4a28, inset 0 0 0 4px #2a1a08, 0 0 18px rgba(0,0,0,0.5)',
      }}>
        <div style={{ position:'absolute', inset: 0, backgroundImage: 'url("data:image/svg+xml,%3Csvg viewBox=\'0 0 100 100\' xmlns=\'http://www.w3.org/2000/svg\'%3E%3Cfilter id=\'l\'%3E%3CfeTurbulence baseFrequency=\'0.9\' numOctaves=\'2\'/%3E%3CfeColorMatrix values=\'0 0 0 0 0.15  0 0 0 0 0.1  0 0 0 0 0.05  0 0 0 0.35 0\'/%3E%3C/filter%3E%3Crect width=\'100%25\' height=\'100%25\' filter=\'url(%23l)\'/%3E%3C/svg%3E")', opacity: 0.6, mixBlendMode: 'multiply' }} />
      </div>
      {/* Children */}
      <div style={{ position: 'relative', height: '100%', zIndex: 2 }}>{children}</div>
    </div>
  );
}

// ── Stat strip at bottom of desk (ink-well meters) ──
function DossierStatStrip({ stats, prevStats, delta, phase }) {
  const keys = ['treasury', 'food', 'stability', 'popular', 'elite'];
  return (
    <div style={{
      display: 'flex',
      gap: 6,
      padding: '6px 10px 0',
    }}>
      {keys.map(k => {
        const d = delta(k);
        const v = stats[k];
        return (
          <div key={k} style={{ flex: 1, textAlign: 'center' }}>
            <div style={{
              fontFamily: '"Special Elite", monospace',
              fontSize: 7, letterSpacing: 0.5,
              color: 'rgba(239,228,201,0.75)',
              textTransform: 'uppercase',
              marginBottom: 2,
            }}>{STAT_META[k].label.split(' ')[0]}</div>
            <div style={{
              position: 'relative',
              height: 4,
              background: 'rgba(0,0,0,0.45)',
              borderRadius: 2,
              overflow: 'hidden',
            }}>
              <div style={{
                position: 'absolute', left: 0, top: 0, bottom: 0,
                width: `${v}%`,
                background: d > 0 ? '#b08830' : d < 0 ? '#8b1818' : '#c89a4a',
                transition: 'width 0.6s ease-out',
              }} />
            </div>
            <div style={{
              fontFamily: '"Special Elite", monospace',
              fontSize: 8,
              color: '#efe4c9',
              marginTop: 2,
              fontWeight: 700,
            }}>
              {v}{phase === 'outcome' && d !== 0 && (
                <span style={{ marginLeft: 3, color: d > 0 ? '#e9c76a' : '#e07070', fontSize: 7 }}>
                  {d > 0 ? `+${d}` : d}
                </span>
              )}
            </div>
          </div>
        );
      })}
    </div>
  );
}

// ── Index-card option (handwritten-feeling, paperclipped to folder) ──
function IndexCardOption({ option, index, onSelect, rotation = 0 }) {
  const [hover, setHover] = _ds_us(false);
  const colorMap = {
    Orthodox: '#8b1818',
    Reformist: '#9a7a30',
    Opportunist: '#3a5a6a',
    'Iron Fist': '#8b1818',
    Cunning: '#3a5a6a',
    Loyal: '#8b1818',
    Independent: '#9a7a30',
    Ambitious: '#6a2828',
  };
  const c = colorMap[option.stance] || '#5a4a32';
  return (
    <button
      onClick={() => onSelect(option)}
      onMouseEnter={() => setHover(true)}
      onMouseLeave={() => setHover(false)}
      style={{
        textAlign: 'left',
        width: '100%',
        background: `linear-gradient(176deg, #f8efd5, #ecdfbd)`,
        border: 'none',
        borderLeft: `2.5px solid ${c}`,
        padding: '10px 12px 10px 14px',
        position: 'relative',
        cursor: 'pointer',
        transform: `rotate(${rotation}deg) ${hover ? 'translateY(-2px)' : ''}`,
        transformOrigin: 'top left',
        boxShadow: hover
          ? '0 6px 14px rgba(0,0,0,0.35), 0 0 0 1px rgba(0,0,0,0.2)'
          : '0 3px 6px rgba(0,0,0,0.28), 0 0 0 1px rgba(0,0,0,0.12)',
        transition: 'transform 0.15s ease, box-shadow 0.15s ease',
        fontFamily: 'inherit',
      }}
    >
      {/* ruled line */}
      <div style={{
        position: 'absolute', left: 14, right: 12, top: 32,
        height: 1, background: 'rgba(90,70,40,0.22)',
      }} />
      <div style={{
        display: 'flex', justifyContent: 'space-between', alignItems: 'baseline',
        marginBottom: 5,
      }}>
        <span style={{
          fontFamily: '"Special Elite", monospace',
          fontSize: 9, color: c,
          letterSpacing: 1.2, textTransform: 'uppercase', fontWeight: 700,
        }}>№ {String(index + 1).padStart(2, '0')} — {option.stance}</span>
        <span style={{
          fontFamily: '"IM Fell English", serif',
          fontSize: 10, fontStyle: 'italic',
          color: 'rgba(90,74,50,0.7)',
        }}>{Object.entries(option.effects).filter(([,v])=>v!==0).length} consequences</span>
      </div>
      <div style={{
        fontFamily: '"IM Fell English", "Playfair Display", serif',
        fontSize: 15, fontWeight: 500,
        color: '#2a2216',
        lineHeight: 1.2,
        marginBottom: 4,
        textWrap: 'pretty',
      }}>{option.label}</div>
      <div style={{
        fontFamily: '"Source Serif 4", serif',
        fontSize: 11, fontStyle: 'italic',
        color: '#5a4a32',
        lineHeight: 1.4,
        textWrap: 'pretty',
      }}>{option.body}</div>
    </button>
  );
}

// ── Margin annotation (hand-scrawled note in red ink) ──
function MarginNote({ text, top, side = 'right' }) {
  return (
    <div style={{
      position: 'absolute',
      top,
      [side]: -8,
      transform: `rotate(${side === 'right' ? -4 : 3}deg)`,
      fontFamily: '"IM Fell English", serif',
      fontStyle: 'italic',
      fontSize: 10,
      color: '#8b1818',
      maxWidth: 90,
      lineHeight: 1.2,
      zIndex: 3,
      pointerEvents: 'none',
    }}>
      <span style={{
        borderBottom: '1px wavy #8b1818',
        borderBottomStyle: 'solid',
      }}>— {text}</span>
    </div>
  );
}

// ── The folder (main briefing container) ──
function Folder({ children, classification }) {
  return (
    <div style={{
      position: 'relative',
      background: '#c9a869',
      padding: '20px 14px 30px',
      marginTop: 8,
      boxShadow: '0 4px 10px rgba(0,0,0,0.45), inset 0 0 0 1px rgba(80,55,25,0.5), inset 2px 2px 0 rgba(255,240,200,0.2)',
      borderRadius: 1,
    }}>
      {/* Folder tab */}
      <div style={{
        position: 'absolute',
        top: -14, left: 20,
        background: '#c9a869',
        padding: '3px 18px 6px',
        fontFamily: '"Special Elite", monospace',
        fontSize: 8,
        color: '#3a2818',
        fontWeight: 700,
        letterSpacing: 1.5,
        whiteSpace: 'nowrap',
        clipPath: 'polygon(0 0, 100% 0, calc(100% - 10px) 100%, 10px 100%)',
        boxShadow: '0 1px 2px rgba(0,0,0,0.25)',
      }}>
        {classification}
      </div>
      {/* inner paper */}
      <div style={{
        background: 'linear-gradient(180deg, #f2e6c5, #efe2bd)',
        padding: '18px 16px 18px',
        boxShadow: 'inset 0 0 20px rgba(120,90,40,0.22)',
        position: 'relative',
      }}>
        {children}
      </div>
    </div>
  );
}

// ── Briefing (typed memo) inside folder ──
function DossierBriefing({ scenario, fromCharacter, onSelect, onHover }) {
  return (
    <div style={{ position: 'relative' }}>
      {/* Paperclip with portrait */}
      <div style={{
        position: 'absolute', top: -30, right: -6, zIndex: 5,
        display: 'flex', flexDirection: 'column', alignItems: 'center',
      }}>
        <DossierPaperclip angle={14} />
      </div>

      <div
        onMouseEnter={() => onHover(fromCharacter)}
        onMouseLeave={() => onHover(null)}
        style={{
          position: 'absolute', top: -16, right: 6, zIndex: 4,
          transform: 'rotate(4deg)',
          cursor: 'help',
        }}
      >
        <DossierPortrait character={fromCharacter} size={58} />
      </div>

      {/* Doc header */}
      <div style={{
        display: 'flex', justifyContent: 'space-between',
        fontFamily: '"Special Elite", monospace',
        fontSize: 8, color: '#5a4a32',
        letterSpacing: 1.5, textTransform: 'uppercase',
        paddingBottom: 6, marginBottom: 10,
        borderBottom: '0.5px solid rgba(42,34,22,0.28)',
        maxWidth: 'calc(100% - 76px)',
      }}>
        <span>{scenario.docNumber}</span>
        <span>{scenario.date}</span>
      </div>

      {/* Bureau */}
      <div style={{
        fontFamily: '"Special Elite", monospace',
        fontSize: 9, color: '#8b1818',
        letterSpacing: 2, textTransform: 'uppercase',
        fontWeight: 700, marginBottom: 4,
        maxWidth: 'calc(100% - 76px)',
      }}>{scenario.bureau}</div>

      {/* Title */}
      <div style={{
        fontFamily: '"IM Fell English", "Playfair Display", serif',
        fontSize: 19, fontWeight: 700,
        lineHeight: 1.15, color: '#2a2216',
        marginBottom: 12,
        maxWidth: 'calc(100% - 76px)',
        textWrap: 'balance',
      }}>{scenario.title}</div>

      {/* Classification stamp */}
      <div style={{ position: 'absolute', top: 60, right: -10, zIndex: 2 }}>
        <DossierStamp text={scenario.classification} color="#8b1818" rotate={9} />
      </div>

      {/* Typed body — using divs to avoid <p> margin collapse quirks */}
      <div style={{
        fontFamily: '"Special Elite", "Courier Prime", monospace',
        fontSize: 11.5, lineHeight: 1.5,
        color: '#3a2a18',
        letterSpacing: 0.1,
        marginTop: 26,
      }}>
        {scenario.briefing.map((p, i) => (
          <div key={i} style={{
            display: 'block',
            marginBottom: 18,
            paddingBottom: 2,
            fontStyle: i === 0 ? 'italic' : 'normal',
          }}>{p}</div>
        ))}
      </div>

      {/* Margin note */}
      {scenario.turn === 1 && <MarginNote text="she will be watching" top={110} side="right" />}
      {scenario.turn === 2 && <MarginNote text="who leaked?" top={100} side="right" />}
      {scenario.turn === 3 && <MarginNote text="burn after reading" top={90} side="right" />}

      {/* Signature + wax */}
      <div style={{
        marginTop: 18,
        display: 'flex', alignItems: 'flex-end', justifyContent: 'space-between',
      }}>
        <div>
          <div style={{
            fontFamily: '"IM Fell English", serif',
            fontStyle: 'italic',
            fontSize: 17,
            color: '#2a2216',
            lineHeight: 1,
            borderBottom: '0.5px solid rgba(42,34,22,0.35)',
            paddingBottom: 2,
            display: 'inline-block',
          }}>{fromCharacter.name}</div>
          <div style={{
            fontFamily: '"Special Elite", monospace',
            fontSize: 8,
            color: '#5a4a32',
            marginTop: 4,
            letterSpacing: 1,
            textTransform: 'uppercase',
          }}>{fromCharacter.rank}</div>
        </div>
        <DossierWax size={54} color="#8b1818" />
      </div>
    </div>
  );
}

// ── Outcome view ──
function DossierOutcome({ option, onNext, stats, delta, phase }) {
  // stamp inline at top of card, not absolute, so it never clips
  return (
    <div style={{ position: 'relative', paddingTop: 4 }}>
      <div style={{
        background: 'linear-gradient(180deg, #f2e6c5, #e8d8ae)',
        padding: '20px 18px',
        boxShadow: 'inset 0 0 20px rgba(120,90,40,0.2), 0 2px 6px rgba(0,0,0,0.3)',
        position: 'relative',
        overflow: 'visible',
      }}>
        <TapeStrip width={70} angle={-3} style={{ position:'absolute', top: -8, left: 30 }} />
        <TapeStrip width={70} angle={2} style={{ position:'absolute', top: -8, right: 30 }} />

        {/* Stamp — inline at top, right-aligned */}
        <div style={{ display: 'flex', justifyContent: 'flex-end', marginBottom: 6, marginRight: 4 }}>
          <DossierStamp text={option.stamp} color="#8b1818" rotate={-6} />
        </div>

        <div style={{
          fontFamily: '"Special Elite", monospace',
          fontSize: 8, color: '#8b1818',
          letterSpacing: 2, textTransform: 'uppercase',
          fontWeight: 700, marginBottom: 6,
          paddingBottom: 4, borderBottom: '0.5px solid rgba(42,34,22,0.25)',
        }}>— ADDENDUM · {option.stance.toUpperCase()}</div>

        <div style={{
          fontFamily: '"IM Fell English", serif',
          fontSize: 20, fontWeight: 700,
          lineHeight: 1.1,
          color: '#2a2216',
          marginBottom: 10,
          textWrap: 'balance',
        }}>{option.outcomeTitle}</div>

        <div style={{
          fontFamily: '"Source Serif 4", Georgia, serif',
          fontSize: 12.5, lineHeight: 1.55,
          color: '#3a2a18',
          fontStyle: 'italic',
          textWrap: 'pretty',
        }}>{option.outcomeBody}</div>

        {/* Effect ledger — single column, cleaner wrap behavior */}
        <div style={{
          marginTop: 14, paddingTop: 10,
          borderTop: '1px dashed rgba(42,34,22,0.25)',
          fontFamily: '"Special Elite", monospace',
          fontSize: 10,
          color: '#5a4a32',
        }}>
          <div style={{ fontSize: 8, letterSpacing: 2, textTransform: 'uppercase', color: '#8b1818', marginBottom: 6, fontWeight: 700 }}>— Consequences</div>
          {Object.entries(option.effects).filter(([,v]) => v !== 0).map(([k,v]) => (
            <div key={k} style={{
              display: 'flex', justifyContent: 'space-between', alignItems: 'baseline',
              padding: '3px 0',
              borderBottom: '1px dotted rgba(90,74,50,0.22)',
              gap: 10,
            }}>
              <span style={{ textTransform: 'uppercase', letterSpacing: 0.8, fontSize: 10, whiteSpace: 'nowrap' }}>{STAT_META[k].label}</span>
              <span style={{
                color: v > 0 ? '#3a6a30' : '#8b1818',
                fontWeight: 700, fontSize: 12,
                fontFamily: '"IM Fell English", serif',
                whiteSpace: 'nowrap',
              }}>{v > 0 ? `+${v}` : v}</span>
            </div>
          ))}
        </div>
      </div>

      <button onClick={onNext} style={{
        marginTop: 14, width: '100%',
        background: 'linear-gradient(180deg, #3a2818, #261808)',
        border: 'none',
        borderTop: '1px solid #6a4a28',
        color: '#efe4c9',
        padding: '12px 14px',
        fontFamily: '"IM Fell English", serif',
        fontSize: 14,
        fontStyle: 'italic',
        cursor: 'pointer',
        letterSpacing: 0.5,
        boxShadow: '0 3px 8px rgba(0,0,0,0.4)',
      }}>
        Proceed to next directive →
      </button>
    </div>
  );
}

// ── Verdict ──
function DossierVerdict({ stats, onRestart }) {
  const score = (stats.stability + stats.popular + stats.elite) / 3;
  const verdict = score > 60 ? 'HERO OF THE PEOPLE' : score > 40 ? 'RELIABLE CADRE' : score > 25 ? 'UNDER REVIEW' : 'LIQUIDATED';
  const line = score > 60 ? 'Your portrait hangs in every schoolroom.' :
               score > 40 ? 'You will be permitted to retire to a cottage in the woods.' :
               score > 25 ? 'A dacha in the north. Bring a coat.' :
               'The paperwork was filed at 0400.';
  return (
    <div style={{
      background: 'linear-gradient(180deg, #f2e6c5, #d9c294)',
      padding: '26px 20px',
      boxShadow: 'inset 0 0 24px rgba(120,90,40,0.28), 0 2px 6px rgba(0,0,0,0.3)',
      textAlign: 'center',
      position: 'relative',
    }}>
      <DossierStamp text="FINAL JUDGMENT" color="#8b1818" rotate={-8} />
      <div style={{
        marginTop: 16,
        fontFamily: '"IM Fell English", serif',
        fontSize: 26, fontWeight: 700,
        color: '#2a2216',
        lineHeight: 1.1,
        textWrap: 'balance',
      }}>{verdict}</div>
      <div style={{
        fontFamily: '"IM Fell English", serif',
        fontStyle: 'italic',
        fontSize: 14,
        color: '#5a4a32',
        marginTop: 10,
        marginBottom: 20,
        textWrap: 'pretty',
      }}>{line}</div>
      <button onClick={onRestart} style={{
        background: 'transparent',
        border: '1px solid #2a2216',
        color: '#2a2216',
        padding: '8px 18px',
        fontFamily: '"Special Elite", monospace',
        fontSize: 10,
        letterSpacing: 2,
        cursor: 'pointer',
        textTransform: 'uppercase',
      }}>Begin Again</button>
    </div>
  );
}

// ── Main DossierScreen ──
function DossierScreen({ onThemeCycle }) {
  const g = useGame();
  const { scenario, fromCharacter, phase, selectedOpt, stats, prevStats,
    selectOption, nextTurn, reset, hoveredChar, setHoveredChar, delta } = g;

  return (
    <div style={{
      height: '100%', width: '100%',
      position: 'relative', overflow: 'hidden',
      fontFamily: '"Source Serif 4", Georgia, serif',
    }}>
      <DeskBlotter>
        {/* Status bar area — dark wood (below iOS status bar) */}
        <div style={{
          position: 'absolute', top: 54, left: 0, right: 0, height: 44,
          padding: '4px 14px',
          display: 'flex', alignItems: 'center', justifyContent: 'space-between',
          zIndex: 10,
        }}>
          <div>
            <div style={{
              fontFamily: '"Special Elite", monospace',
              fontSize: 8, color: 'rgba(239,228,201,0.55)',
              letterSpacing: 2, textTransform: 'uppercase',
            }}>PSRA · OFFICE OF THE SECRETARY</div>
            <div style={{
              fontFamily: '"IM Fell English", serif',
              fontSize: 17, fontWeight: 700,
              color: '#efe4c9',
              lineHeight: 1,
              letterSpacing: 0.3,
            }}>The Apparatus</div>
          </div>
          <button onClick={reset} style={{
            background: 'transparent',
            border: '1px solid rgba(239,228,201,0.3)',
            color: 'rgba(239,228,201,0.7)',
            padding: '3px 9px',
            fontFamily: '"Special Elite", monospace',
            fontSize: 8,
            letterSpacing: 1.5,
            cursor: 'pointer',
            textTransform: 'uppercase',
          }}>Reset</button>
        </div>

        {/* Scrollable content area */}
        <div style={{
          position: 'absolute', top: 104, left: 16, right: 16, bottom: 74,
          overflowY: 'auto', overflowX: 'hidden',
          padding: '10px 0 20px',
        }}>
          {phase === 'briefing' && (
            <>
              <Folder classification={`TURN ${scenario.turn}/${SCENARIOS.length} · ${scenario.classification}`}>
                <DossierBriefing
                  scenario={scenario}
                  fromCharacter={fromCharacter}
                  onSelect={selectOption}
                  onHover={setHoveredChar}
                />
              </Folder>

              {/* Divider */}
              <div style={{
                margin: '18px 8px 10px',
                textAlign: 'center',
                fontFamily: '"Special Elite", monospace',
                fontSize: 8,
                color: 'rgba(239,228,201,0.55)',
                letterSpacing: 3,
                textTransform: 'uppercase',
              }}>— Your Directive —</div>

              {/* Index-card options */}
              <div style={{ display: 'flex', flexDirection: 'column', gap: 9, padding: '0 4px' }}>
                {scenario.options.map((opt, i) => (
                  <IndexCardOption
                    key={opt.id}
                    option={opt}
                    index={i}
                    onSelect={selectOption}
                    rotation={i === 0 ? -0.5 : i === 1 ? 0.3 : -0.2}
                  />
                ))}
              </div>
            </>
          )}

          {phase === 'outcome' && selectedOpt && (
            <DossierOutcome
              option={selectedOpt}
              onNext={nextTurn}
              stats={stats}
              delta={delta}
              phase={phase}
            />
          )}

          {phase === 'verdict' && (
            <DossierVerdict stats={stats} onRestart={reset} />
          )}
        </div>

        {/* Bottom strip — stats + theme cycler */}
        <div style={{
          position: 'absolute', bottom: 0, left: 0, right: 0,
          background: 'linear-gradient(180deg, #2a1a08, #1a1004)',
          borderTop: '1px solid #5a3e1e',
          padding: '6px 8px 22px',
          zIndex: 10,
        }}>
          <DossierStatStrip stats={stats} prevStats={prevStats} delta={delta} phase={phase} />
          <div style={{
            marginTop: 6,
            display: 'flex', justifyContent: 'space-between', alignItems: 'center',
          }}>
            <div style={{
              fontFamily: '"Special Elite", monospace',
              fontSize: 7, letterSpacing: 2,
              color: 'rgba(239,228,201,0.55)',
              textTransform: 'uppercase',
            }}>
              {phase === 'briefing' ? 'awaiting directive' : phase === 'outcome' ? 'directive filed' : 'session closed'}
            </div>
            <button onClick={onThemeCycle} style={{
              background: 'transparent',
              border: '1px solid rgba(239,228,201,0.25)',
              color: 'rgba(239,228,201,0.75)',
              padding: '2px 8px',
              fontFamily: '"Special Elite", monospace',
              fontSize: 7, letterSpacing: 1.5,
              cursor: 'pointer',
              textTransform: 'uppercase',
            }}>
              ▸ Cycle theme
            </button>
          </div>
        </div>

        {/* Dossier hover card */}
        {hoveredChar && (
          <div style={{
            position: 'absolute', bottom: 64, left: 16, right: 16,
            background: 'linear-gradient(180deg, #f2e6c5, #e5d39b)',
            border: '1px solid #8a6a3a',
            padding: '10px 12px',
            boxShadow: '0 4px 14px rgba(0,0,0,0.5)',
            zIndex: 20,
            fontFamily: '"Source Serif 4", serif',
          }}>
            <div style={{
              fontFamily: '"Special Elite", monospace',
              fontSize: 8, color: '#8b1818', letterSpacing: 1.5,
              textTransform: 'uppercase', fontWeight: 700,
            }}>DOSSIER — {hoveredChar.relation}</div>
            <div style={{
              fontFamily: '"IM Fell English", serif',
              fontSize: 15, fontWeight: 700, color: '#2a2216', lineHeight: 1.1,
              marginTop: 2,
            }}>{hoveredChar.name}</div>
            <div style={{
              fontFamily: '"Special Elite", monospace',
              fontSize: 8, color: '#5a4a32', marginTop: 2, marginBottom: 6,
              letterSpacing: 0.5, textTransform: 'uppercase',
            }}>{hoveredChar.rank}</div>
            {hoveredChar.dossier.map((d, i) => (
              <div key={i} style={{
                fontSize: 10.5, fontStyle: 'italic',
                color: '#3a2a18', lineHeight: 1.4, marginBottom: 3,
              }}>— {d}</div>
            ))}
          </div>
        )}
      </DeskBlotter>
    </div>
  );
}

Object.assign(window, { DossierScreen });
