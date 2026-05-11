// redacted-screen.jsx — REDACTED FILE variation
// METAPHOR: a declassified intelligence document from a paranoid archive.
// Black redaction bars over text, CLASSIFIED watermarks, typewriter type,
// three-box "STANCE REVIEW" form at bottom, teletype header scrolling,
// green-phosphor stat readouts. Dark. Cold. Surveillance aesthetic.

const { useState: _rs_us, useEffect: _rs_ue, useRef: _rs_ur } = React;

// ─────────── Redaction bar ───────────
function RedactBar({ width = 60, height = 12, style = {} }) {
  return (
    <span style={{
      display: 'inline-block',
      width, height,
      background: '#0a0806',
      verticalAlign: 'middle',
      margin: '0 2px',
      boxShadow: 'inset 0 0 0 1px #2a2218',
      ...style,
    }} />
  );
}

// ─────────── CLASSIFIED watermark (diagonal, tiled) ───────────
function ClassifiedWatermark({ text = 'CLASSIFIED' }) {
  return (
    <div style={{
      position: 'absolute', inset: 0,
      pointerEvents: 'none',
      overflow: 'hidden',
      opacity: 0.035,
      zIndex: 1,
    }}>
      <div style={{
        position: 'absolute',
        top: '-50%', left: '-50%',
        width: '200%', height: '200%',
        transform: 'rotate(-32deg)',
        fontFamily: '"Special Elite", monospace',
        fontSize: 26,
        fontWeight: 700,
        color: '#d4c8a8',
        letterSpacing: 4,
        lineHeight: 1.6,
        whiteSpace: 'nowrap',
      }}>
        {Array.from({ length: 22 }).map((_, i) => (
          <div key={i}>{Array.from({ length: 10 }).map((__, j) => text + '  ').join('')}</div>
        ))}
      </div>
    </div>
  );
}

// ─────────── Teletype strip (scrolling header) ───────────
function TeletypeStrip({ scenario }) {
  const msg = `  ▸  PSRA SECURE WIRE  ▸  ${scenario.docNumber}  ▸  ${scenario.classification}  ▸  ${scenario.date}  ▸  ORIGIN: ${scenario.bureau.toUpperCase()}  ▸  EYES ONLY  `;
  return (
    <div style={{
      background: '#0a0806',
      borderTop: '1px solid rgba(212,200,168,0.15)',
      borderBottom: '1px solid rgba(212,200,168,0.15)',
      overflow: 'hidden',
      padding: '3px 0',
      position: 'relative',
    }}>
      <div style={{
        display: 'inline-block',
        whiteSpace: 'nowrap',
        animation: 'redacted-teletype 42s linear infinite',
        fontFamily: '"JetBrains Mono", monospace',
        fontSize: 9,
        color: '#7a9a6a',
        letterSpacing: 1.5,
      }}>
        {(msg + msg + msg).repeat(2)}
      </div>
    </div>
  );
}

// ─────────── Stamp (red, aggressive) ───────────
function RedactedStamp({ text, rotate = -6, size = 1 }) {
  return (
    <div style={{
      display: 'inline-block',
      border: `2.5px solid #c72828`,
      color: '#c72828',
      padding: `${4 * size}px ${12 * size}px`,
      fontFamily: '"Special Elite", monospace',
      fontWeight: 700,
      fontSize: 11 * size,
      letterSpacing: 2,
      transform: `rotate(${rotate}deg)`,
      textTransform: 'uppercase',
      opacity: 0.78,
      whiteSpace: 'nowrap',
      boxShadow: 'inset 0 0 0 1px rgba(199,40,40,0.3)',
    }}>{text}</div>
  );
}

// ─────────── File number box (form-style) ───────────
function FormField({ label, value, flex = 1 }) {
  return (
    <div style={{
      flex,
      borderRight: '1px solid rgba(212,200,168,0.18)',
      padding: '6px 10px',
      minWidth: 0,
    }}>
      <div style={{
        fontFamily: '"JetBrains Mono", monospace',
        fontSize: 7, letterSpacing: 1.5,
        color: '#6a5e48',
        textTransform: 'uppercase',
        marginBottom: 2,
      }}>{label}</div>
      <div style={{
        fontFamily: '"Special Elite", monospace',
        fontSize: 11,
        color: '#d4c8a8',
        fontWeight: 500,
        whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis',
      }}>{value}</div>
    </div>
  );
}

// ─────────── Stat monitor (green phosphor readout) ───────────
function StatMonitor({ stats, delta, phase }) {
  const keys = ['treasury', 'food', 'stability', 'popular', 'elite'];
  return (
    <div style={{
      background: '#050605',
      border: '1px solid #2a3a2a',
      padding: '8px 10px',
      boxShadow: 'inset 0 0 14px rgba(40,160,80,0.12)',
      marginTop: 8,
    }}>
      <div style={{
        fontFamily: '"JetBrains Mono", monospace',
        fontSize: 7, letterSpacing: 2,
        color: '#4a7a4a',
        textTransform: 'uppercase',
        marginBottom: 6,
        display: 'flex', justifyContent: 'space-between',
      }}>
        <span>► STATE INDICATORS</span>
        <span style={{ color: '#7aaa7a' }}>◉ LIVE</span>
      </div>
      {keys.map(k => {
        const v = stats[k];
        const d = delta(k);
        const cells = 20;
        const filled = Math.round((v / 100) * cells);
        return (
          <div key={k} style={{
            display: 'flex', alignItems: 'center', gap: 8,
            marginBottom: 3,
            fontFamily: '"JetBrains Mono", monospace',
            fontSize: 9,
          }}>
            <div style={{
              width: 52,
              color: '#7aaa7a',
              textTransform: 'uppercase',
              letterSpacing: 1,
              fontSize: 8,
            }}>{STAT_META[k].label.split(' ')[0]}</div>
            <div style={{ flex: 1, display: 'flex', gap: 1 }}>
              {Array.from({ length: cells }).map((_, i) => (
                <div key={i} style={{
                  flex: 1, height: 9,
                  background: i < filled
                    ? (d > 0 ? '#7aee7a' : d < 0 && i >= filled - Math.abs(d/5) ? '#ee6a6a' : '#4a8a4a')
                    : '#0f1a0f',
                  boxShadow: i < filled ? '0 0 3px rgba(120,220,120,0.45)' : 'none',
                  transition: 'background 0.4s',
                }} />
              ))}
            </div>
            <div style={{
              width: 42,
              textAlign: 'right',
              color: '#aaeea0',
              fontWeight: 700,
            }}>
              {String(v).padStart(3, '0')}
              {phase === 'outcome' && d !== 0 && (
                <span style={{
                  marginLeft: 4,
                  color: d > 0 ? '#aaeea0' : '#ee8080',
                  fontSize: 8,
                }}>{d > 0 ? `+${d}` : d}</span>
              )}
            </div>
          </div>
        );
      })}
    </div>
  );
}

// ─────────── Redacted briefing (with black bars) ───────────
function RedactedBriefing({ scenario, fromCharacter, onHover }) {
  // Decide which words to redact based on turn
  const redactWord = (text, pattern) => {
    return text.split(pattern).map((part, i, arr) => (
      <React.Fragment key={i}>
        {part}
        {i < arr.length - 1 && <RedactBar width={60 + Math.random() * 40} height={11} />}
      </React.Fragment>
    ));
  };

  // simple regex-based redaction: redact proper nouns that aren't the sender
  const redactText = (text) => {
    // match capitalized words that are likely names/places
    const parts = text.split(/\b(Volkov|Petrenko|Hollis|Ashford|Ohio|Chicago|Nebraska|Iowa|Jefferson|Collective|Tribune|Central Committee|Internal Troops|Commissar|Chairman)\b/);
    return parts.map((part, i) => {
      if (/^(Volkov|Petrenko|Hollis|Ashford|Ohio|Chicago|Nebraska|Iowa|Jefferson|Collective|Tribune|Central Committee|Internal Troops|Commissar|Chairman)$/.test(part)) {
        const w = part.length * 6.5 + 6;
        return <RedactBar key={i} width={w} height={11} />;
      }
      return <React.Fragment key={i}>{part}</React.Fragment>;
    });
  };

  return (
    <div style={{
      background: '#1a1812',
      border: '1px solid rgba(212,200,168,0.22)',
      position: 'relative',
      boxShadow: '0 2px 8px rgba(0,0,0,0.5)',
    }}>
      <ClassifiedWatermark text={scenario.classification.replace(' ', '•')} />

      {/* Form header bar */}
      <div style={{
        display: 'flex',
        borderBottom: '1px solid rgba(212,200,168,0.22)',
        background: 'linear-gradient(180deg, #23201a, #1a1812)',
        position: 'relative', zIndex: 2,
      }}>
        <FormField label="FORM" value={`PSRA-${scenario.docNumber.slice(0, 3)}`} flex={0.8} />
        <FormField label="REF NO." value={scenario.docNumber} flex={1.2} />
        <FormField label="BUREAU" value={scenario.bureau.replace('Bureau of ', 'B.').toUpperCase()} flex={1} />
      </div>

      {/* Big classified stripe */}
      <div style={{
        background: '#c72828',
        color: '#000',
        padding: '5px 10px',
        fontFamily: '"Special Elite", monospace',
        fontSize: 11,
        fontWeight: 700,
        letterSpacing: 3,
        textAlign: 'center',
        textTransform: 'uppercase',
        position: 'relative', zIndex: 2,
      }}>
        ▓▓▓  {scenario.classification}  ·  HANDLE VIA NSI CHANNELS ONLY  ▓▓▓
      </div>

      {/* Title + sender */}
      <div style={{ padding: '14px 14px 10px', position: 'relative', zIndex: 2 }}>
        <div style={{
          fontFamily: '"JetBrains Mono", monospace',
          fontSize: 8, color: '#6a5e48',
          letterSpacing: 2, textTransform: 'uppercase',
          marginBottom: 4,
        }}>SUBJECT / 3.1</div>
        <div style={{
          fontFamily: '"Special Elite", monospace',
          fontSize: 16, fontWeight: 700,
          color: '#e5d9b9',
          lineHeight: 1.2,
          marginBottom: 12,
          textWrap: 'balance',
        }}>{scenario.title}</div>

        {/* Sender as a mug-shot card */}
        <div
          onMouseEnter={() => onHover(fromCharacter)}
          onMouseLeave={() => onHover(null)}
          style={{
            display: 'flex', alignItems: 'center', gap: 10,
            padding: '8px 10px',
            background: '#0f0e0a',
            border: '1px solid rgba(212,200,168,0.18)',
            marginBottom: 12,
            cursor: 'help',
          }}>
          <div style={{
            width: 36, height: 42,
            background: '#3a3a3a',
            border: '1px solid rgba(212,200,168,0.25)',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            fontFamily: '"JetBrains Mono", monospace',
            fontSize: 13, fontWeight: 700,
            color: '#d4c8a8',
            position: 'relative',
          }}>
            {fromCharacter.initials}
            <div style={{
              position: 'absolute', bottom: -1, left: 0, right: 0,
              fontSize: 5, textAlign: 'center',
              color: '#6a5e48', letterSpacing: 0.5,
              background: '#0f0e0a',
              padding: '1px 0',
            }}>SUBJECT</div>
          </div>
          <div style={{ flex: 1, minWidth: 0 }}>
            <div style={{
              fontFamily: '"JetBrains Mono", monospace',
              fontSize: 7, letterSpacing: 1.5,
              color: '#6a5e48', textTransform: 'uppercase',
            }}>ORIGIN</div>
            <div style={{
              fontFamily: '"Special Elite", monospace',
              fontSize: 12, color: '#e5d9b9', fontWeight: 700,
            }}>{fromCharacter.name}</div>
            <div style={{
              fontFamily: '"JetBrains Mono", monospace',
              fontSize: 8,
              color: '#9a8e70',
              letterSpacing: 0.5,
            }}>{fromCharacter.rank}</div>
          </div>
          <div style={{
            fontFamily: '"JetBrains Mono", monospace',
            fontSize: 7,
            color: '#6a5e48',
            letterSpacing: 1,
            textTransform: 'uppercase',
            textAlign: 'right',
            lineHeight: 1.3,
          }}>
            REL:<br />
            <span style={{ color: '#c72828', fontWeight: 700 }}>
              {fromCharacter.relation.toUpperCase()}
            </span>
          </div>
        </div>

        {/* Briefing text with redactions */}
        <div style={{
          fontFamily: '"Special Elite", "Courier Prime", monospace',
          fontSize: 11, lineHeight: 1.55,
          color: '#d4c8a8',
          padding: '4px 0',
        }}>
          {scenario.briefing.map((p, i) => (
            <p key={i} style={{
              margin: '0 0 14px',
              display: 'block',
              fontStyle: i === 0 ? 'italic' : 'normal',
              color: i === 0 ? '#9a8e70' : '#d4c8a8',
            }}>{redactText(p)}</p>
          ))}
        </div>

        {/* Signature line */}
        <div style={{
          marginTop: 12, paddingTop: 10,
          borderTop: '1px dashed rgba(212,200,168,0.22)',
          display: 'flex', justifyContent: 'space-between', alignItems: 'center',
          fontFamily: '"JetBrains Mono", monospace',
          fontSize: 8, color: '#6a5e48',
          letterSpacing: 1.5, textTransform: 'uppercase',
        }}>
          <span>/S/ <span style={{ color: '#9a8e70' }}>{fromCharacter.name.split(' ').map(n => n[0]).join('.')}.</span></span>
          <span>END TRANSMISSION</span>
        </div>
      </div>

      {/* Classification stamp absolute */}
      <div style={{
        position: 'absolute', top: 90, right: -6, zIndex: 5,
      }}>
        <RedactedStamp text={scenario.classification} rotate={7} />
      </div>
    </div>
  );
}

// ─────────── Stance review form (bottom of briefing) ───────────
function StanceReviewForm({ scenario, onSelect }) {
  const [hover, setHover] = _rs_us(null);
  return (
    <div style={{
      marginTop: 12,
      background: '#1a1812',
      border: '1px solid rgba(212,200,168,0.22)',
      position: 'relative',
    }}>
      {/* Header */}
      <div style={{
        background: 'linear-gradient(180deg, #2a2218, #1a1812)',
        padding: '8px 12px',
        borderBottom: '1px solid rgba(212,200,168,0.22)',
        display: 'flex', justifyContent: 'space-between', alignItems: 'center',
      }}>
        <div style={{
          fontFamily: '"JetBrains Mono", monospace',
          fontSize: 8, letterSpacing: 2.5,
          color: '#c72828', textTransform: 'uppercase',
          fontWeight: 700,
        }}>§ 4.0 — OFFICER'S DIRECTIVE</div>
        <div style={{
          fontFamily: '"JetBrains Mono", monospace',
          fontSize: 7, letterSpacing: 1,
          color: '#6a5e48', textTransform: 'uppercase',
        }}>SELECT ONE</div>
      </div>

      {/* Options as form rows */}
      {scenario.options.map((opt, i) => {
        const isHover = hover === opt.id;
        return (
          <button
            key={opt.id}
            onClick={() => onSelect(opt)}
            onMouseEnter={() => setHover(opt.id)}
            onMouseLeave={() => setHover(null)}
            style={{
              width: '100%',
              textAlign: 'left',
              background: isHover ? '#2a2318' : 'transparent',
              border: 'none',
              borderBottom: i < scenario.options.length - 1 ? '1px solid rgba(212,200,168,0.14)' : 'none',
              padding: '10px 12px 10px 14px',
              cursor: 'pointer',
              fontFamily: 'inherit',
              color: '#d4c8a8',
              position: 'relative',
              transition: 'background 0.1s',
            }}>
            {/* Checkbox */}
            <div style={{
              display: 'flex', alignItems: 'flex-start', gap: 10,
            }}>
              <div style={{
                width: 14, height: 14,
                border: `1px solid ${isHover ? '#c72828' : '#6a5e48'}`,
                flexShrink: 0,
                marginTop: 2,
                position: 'relative',
                background: '#0a0806',
              }}>
                {isHover && (
                  <div style={{
                    position: 'absolute', inset: 2,
                    background: '#c72828',
                    boxShadow: '0 0 6px #c72828',
                  }} />
                )}
              </div>
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{
                  display: 'flex', justifyContent: 'space-between', alignItems: 'baseline', gap: 8,
                  marginBottom: 3,
                }}>
                  <div style={{
                    fontFamily: '"JetBrains Mono", monospace',
                    fontSize: 8, letterSpacing: 1.5,
                    color: '#c72828', textTransform: 'uppercase',
                    fontWeight: 700,
                  }}>
                    § 4.{i + 1} — {opt.stance}
                  </div>
                  <div style={{
                    fontFamily: '"JetBrains Mono", monospace',
                    fontSize: 7,
                    color: '#6a5e48',
                    letterSpacing: 1,
                    whiteSpace: 'nowrap',
                  }}>
                    PRJ. IMPACT: {Object.values(opt.effects).reduce((a, b) => Math.abs(a) + Math.abs(b), 0)}
                  </div>
                </div>
                <div style={{
                  fontFamily: '"Special Elite", monospace',
                  fontSize: 13, fontWeight: 500,
                  color: '#e5d9b9',
                  lineHeight: 1.25,
                  marginBottom: 3,
                  textWrap: 'pretty',
                }}>{opt.label}</div>
                <div style={{
                  fontFamily: '"JetBrains Mono", monospace',
                  fontSize: 10,
                  color: '#9a8e70',
                  lineHeight: 1.4,
                  fontStyle: 'italic',
                  textWrap: 'pretty',
                }}>{opt.body}</div>
              </div>
            </div>
          </button>
        );
      })}
    </div>
  );
}

// ─────────── Outcome ───────────
function RedactedOutcome({ option, stats, delta, onNext, phase }) {
  return (
    <div style={{
      position: 'relative', marginTop: 4,
    }}>
      {/* Big stamp */}
      <div style={{
        position: 'absolute', top: -8, right: 10, zIndex: 10,
      }}>
        <RedactedStamp text={option.stamp} rotate={-9} size={1.1} />
      </div>

      <div style={{
        background: '#1a1812',
        border: '1px solid rgba(212,200,168,0.22)',
        position: 'relative',
        overflow: 'hidden',
      }}>
        <ClassifiedWatermark text="ACTION TAKEN" />

        {/* Header */}
        <div style={{
          background: '#0a0806',
          borderBottom: '1px solid rgba(212,200,168,0.22)',
          padding: '6px 12px',
          display: 'flex', justifyContent: 'space-between', alignItems: 'center',
        }}>
          <div style={{
            fontFamily: '"JetBrains Mono", monospace',
            fontSize: 8, letterSpacing: 2,
            color: '#c72828', textTransform: 'uppercase',
            fontWeight: 700,
          }}>▼ ADDENDUM — POST-DIRECTIVE REPORT</div>
          <div style={{
            fontFamily: '"JetBrains Mono", monospace',
            fontSize: 7, color: '#6a5e48', letterSpacing: 1,
          }}>FILED {new Date().toISOString().slice(0, 10)}</div>
        </div>

        <div style={{ padding: '14px 14px', position: 'relative', zIndex: 2 }}>
          <div style={{
            fontFamily: '"JetBrains Mono", monospace',
            fontSize: 8, letterSpacing: 1.5,
            color: '#9a8e70',
            textTransform: 'uppercase',
            marginBottom: 4,
          }}>DIRECTIVE — {option.stance}</div>
          <div style={{
            fontFamily: '"Special Elite", monospace',
            fontSize: 18, fontWeight: 700,
            color: '#e5d9b9',
            lineHeight: 1.15,
            marginBottom: 10,
            textWrap: 'balance',
          }}>{option.outcomeTitle}</div>
          <div style={{
            fontFamily: '"Special Elite", "Courier Prime", monospace',
            fontSize: 11.5, lineHeight: 1.55,
            color: '#d4c8a8',
            padding: '4px 0',
          }}>
            {option.outcomeBody.split('\n').map((line, i) => (
              <div key={i} style={{ marginBottom: 12 }}>{line}</div>
            ))}
          </div>

          {/* Consequences table — single column, fits narrow */}
          <div style={{
            marginTop: 14, paddingTop: 10,
            borderTop: '1px dashed rgba(212,200,168,0.22)',
          }}>
            <div style={{
              fontFamily: '"JetBrains Mono", monospace',
              fontSize: 7, letterSpacing: 2,
              color: '#6a5e48',
              textTransform: 'uppercase',
              marginBottom: 6,
            }}>§ 5 — ASSESSED IMPACT</div>
            <div style={{ fontFamily: '"JetBrains Mono", monospace', fontSize: 10 }}>
              {Object.entries(option.effects).filter(([,v]) => v !== 0).map(([k,v]) => (
                <div key={k} style={{
                  display: 'flex', justifyContent: 'space-between', alignItems: 'center',
                  padding: '3px 0',
                  borderBottom: '1px dotted rgba(212,200,168,0.12)',
                  gap: 10,
                }}>
                  <span style={{
                    color: '#9a8e70', textTransform: 'uppercase',
                    letterSpacing: 0.8, fontSize: 9.5,
                    whiteSpace: 'nowrap',
                  }}>{STAT_META[k].label}</span>
                  <span style={{
                    color: v > 0 ? '#7aee7a' : '#ee6a6a',
                    fontWeight: 700, fontSize: 11,
                    whiteSpace: 'nowrap',
                  }}>{v > 0 ? `+${v}` : v}</span>
                </div>
              ))}
            </div>
          </div>
        </div>
      </div>

      <button onClick={onNext} style={{
        marginTop: 12, width: '100%',
        background: 'linear-gradient(180deg, #c72828, #8a1818)',
        border: 'none',
        color: '#fff',
        padding: '12px 14px',
        fontFamily: '"JetBrains Mono", monospace',
        fontSize: 11,
        fontWeight: 700,
        letterSpacing: 3,
        cursor: 'pointer',
        textTransform: 'uppercase',
        boxShadow: '0 2px 8px rgba(199,40,40,0.35)',
      }}>
        ▸ Request Next Directive
      </button>
    </div>
  );
}

// ─────────── Verdict ───────────
function RedactedVerdict({ stats, onRestart }) {
  const score = (stats.stability + stats.popular + stats.elite) / 3;
  const verdict = score > 60 ? 'HERO OF THE APPARATUS' : score > 40 ? 'IN GOOD STANDING' : score > 25 ? 'UNDER REVIEW' : 'DISAPPEARED';
  const line = score > 60 ? 'Commendation recorded. Portrait commissioned.' :
               score > 40 ? 'File retained. Career viable.' :
               score > 25 ? 'Reassignment pending. Cold region likely.' :
               'Record sealed. Next of kin not notified.';
  return (
    <div style={{
      background: '#1a1812',
      border: '1px solid rgba(212,200,168,0.22)',
      padding: '22px 18px',
      textAlign: 'center',
      position: 'relative',
    }}>
      <ClassifiedWatermark text="FINAL" />
      <div style={{ position: 'relative', zIndex: 2 }}>
        <RedactedStamp text="FINAL DISPOSITION" rotate={-5} size={1.15} />
        <div style={{
          marginTop: 16,
          fontFamily: '"Special Elite", monospace',
          fontSize: 22, fontWeight: 700,
          color: '#e5d9b9',
          letterSpacing: 1,
          lineHeight: 1.15,
          textWrap: 'balance',
        }}>{verdict}</div>
        <div style={{
          fontFamily: '"JetBrains Mono", monospace',
          fontSize: 11,
          color: '#9a8e70',
          marginTop: 10, marginBottom: 20,
          fontStyle: 'italic',
          textWrap: 'pretty',
        }}>{line}</div>
        <button onClick={onRestart} style={{
          background: 'transparent',
          border: '1px solid #c72828',
          color: '#c72828',
          padding: '8px 18px',
          fontFamily: '"JetBrains Mono", monospace',
          fontSize: 10, fontWeight: 700,
          letterSpacing: 2.5,
          cursor: 'pointer',
          textTransform: 'uppercase',
        }}>▸ Reopen File</button>
      </div>
    </div>
  );
}

// ─────────── Main RedactedScreen ───────────
function RedactedScreen({ onThemeCycle }) {
  const g = useGame();
  const { scenario, fromCharacter, phase, selectedOpt, stats, prevStats,
    selectOption, nextTurn, reset, hoveredChar, setHoveredChar, delta } = g;

  return (
    <div style={{
      height: '100%', width: '100%',
      background: '#0a0806',
      color: '#d4c8a8',
      fontFamily: '"JetBrains Mono", monospace',
      position: 'relative',
      overflow: 'hidden',
      display: 'flex', flexDirection: 'column',
    }}>
      <style>{`
        @keyframes redacted-teletype {
          from { transform: translateX(0); }
          to { transform: translateX(-50%); }
        }
        @keyframes redacted-flicker {
          0%, 100% { opacity: 1; }
          50% { opacity: 0.94; }
        }
      `}</style>

      {/* CRT scanlines */}
      <div style={{
        position: 'absolute', inset: 0, pointerEvents: 'none',
        backgroundImage: 'repeating-linear-gradient(180deg, rgba(212,200,168,0.02) 0, rgba(212,200,168,0.02) 1px, transparent 1px, transparent 3px)',
        zIndex: 50,
        mixBlendMode: 'overlay',
      }} />

      {/* Status bar area */}
      <div style={{
        padding: '54px 12px 8px',
        background: '#050403',
        borderBottom: '1px solid rgba(212,200,168,0.18)',
        display: 'flex', justifyContent: 'space-between', alignItems: 'flex-end',
        gap: 10,
        position: 'relative', zIndex: 4,
      }}>
        <div style={{ minWidth: 0, flex: 1 }}>
          <div style={{
            fontFamily: '"JetBrains Mono", monospace',
            fontSize: 7, letterSpacing: 2,
            color: '#6a5e48', textTransform: 'uppercase',
            whiteSpace: 'nowrap',
          }}>DECLASSIFIED / EYES ONLY · TURN {scenario.turn}/{SCENARIOS.length}</div>
          <div style={{
            fontFamily: '"Special Elite", monospace',
            fontSize: 15, fontWeight: 700,
            color: '#c72828',
            letterSpacing: 1.5,
            textTransform: 'uppercase',
            lineHeight: 1,
            marginTop: 2,
          }}>THE APPARATUS</div>
        </div>
        <div style={{ display: 'flex', gap: 6, alignItems: 'center', flexShrink: 0 }}>
          <div style={{
            fontFamily: '"JetBrains Mono", monospace',
            fontSize: 8, color: '#7aaa7a',
            letterSpacing: 1,
            whiteSpace: 'nowrap',
          }}>◉</div>
          <button onClick={reset} style={{
            background: 'transparent',
            border: '1px solid rgba(212,200,168,0.2)',
            color: '#9a8e70',
            padding: '3px 8px',
            fontFamily: '"JetBrains Mono", monospace',
            fontSize: 8, letterSpacing: 1.5,
            cursor: 'pointer',
            textTransform: 'uppercase',
            whiteSpace: 'nowrap',
          }}>Reset</button>
        </div>
      </div>

      {/* Teletype strip */}
      <TeletypeStrip scenario={scenario} />

      {/* Body */}
      <div style={{
        flex: 1,
        overflowY: 'auto', overflowX: 'hidden',
        padding: '10px 12px 90px',
        position: 'relative',
        zIndex: 2,
      }}>
        {phase === 'briefing' && (
          <>
            <RedactedBriefing
              scenario={scenario}
              fromCharacter={fromCharacter}
              onHover={setHoveredChar}
            />
            <StanceReviewForm
              scenario={scenario}
              onSelect={selectOption}
            />
          </>
        )}
        {/* taller padding only during briefing (so it clears the stat monitor) */}
        {phase === 'briefing' && <div style={{ height: 140 }} />}
        {phase === 'outcome' && selectedOpt && (
          <RedactedOutcome
            option={selectedOpt}
            stats={stats}
            delta={delta}
            onNext={nextTurn}
            phase={phase}
          />
        )}
        {phase === 'verdict' && (
          <RedactedVerdict stats={stats} onRestart={reset} />
        )}
      </div>

      {/* Bottom strip with stat monitor */}
      <div style={{
        position: 'absolute', bottom: 0, left: 0, right: 0,
        background: '#0a0806',
        borderTop: '1px solid rgba(212,200,168,0.2)',
        padding: '4px 10px 14px',
        zIndex: 10,
      }}>
        <StatMonitor stats={stats} delta={delta} phase={phase} />
        <div style={{
          display: 'flex', justifyContent: 'space-between', alignItems: 'center',
          marginTop: 6,
        }}>
          <div style={{
            fontFamily: '"JetBrains Mono", monospace',
            fontSize: 7, letterSpacing: 2,
            color: '#6a5e48',
            textTransform: 'uppercase',
          }}>
            {phase === 'briefing' ? '▸ awaiting directive' : phase === 'outcome' ? '▸ directive executed' : '▸ file closed'}
          </div>
          <button onClick={onThemeCycle} style={{
            background: 'transparent',
            border: '1px solid rgba(212,200,168,0.22)',
            color: '#9a8e70',
            padding: '2px 8px',
            fontFamily: '"JetBrains Mono", monospace',
            fontSize: 7, letterSpacing: 1.5,
            cursor: 'pointer',
            textTransform: 'uppercase',
          }}>
            ▸ Cycle theme
          </button>
        </div>
      </div>

      {/* Hovered dossier card */}
      {hoveredChar && (
        <div style={{
          position: 'absolute', bottom: 54, left: 12, right: 12,
          background: '#1a1812',
          border: '1px solid rgba(212,200,168,0.28)',
          borderLeft: '3px solid #c72828',
          padding: '8px 10px',
          boxShadow: '0 4px 14px rgba(0,0,0,0.65)',
          zIndex: 20,
          fontFamily: '"JetBrains Mono", monospace',
        }}>
          <div style={{
            fontSize: 7, color: '#c72828',
            letterSpacing: 2, textTransform: 'uppercase',
            fontWeight: 700, marginBottom: 3,
          }}>▸ SUBJECT FILE — {hoveredChar.relation}</div>
          <div style={{
            fontFamily: '"Special Elite", monospace',
            fontSize: 13, fontWeight: 700, color: '#e5d9b9', lineHeight: 1.1,
          }}>{hoveredChar.name}</div>
          <div style={{
            fontSize: 8, color: '#9a8e70',
            marginTop: 2, marginBottom: 5,
            letterSpacing: 0.5, textTransform: 'uppercase',
          }}>{hoveredChar.rank}</div>
          {hoveredChar.dossier.map((d, i) => (
            <div key={i} style={{
              fontSize: 9.5, color: '#d4c8a8', lineHeight: 1.35, marginBottom: 2,
              fontFamily: '"Special Elite", monospace',
            }}>▸ {d}</div>
          ))}
        </div>
      )}
    </div>
  );
}

Object.assign(window, { RedactedScreen });
