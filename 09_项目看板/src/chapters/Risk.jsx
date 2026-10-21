import React from "react";
import {useLiveFrame} from "../live/LiveClock";
import {C, MONO} from "../theme";
import {Frame} from "../components/Frame";
import {Card, Chip, SectionLabel} from "../components/UI";
import {enter, scaleIn} from "../components/anim";

const levelColor = (level) =>
  level === "high" ? C.red : level === "medium" ? C.amber : C.cyan;

const RiskMatrix = ({data}) => {
  const frame = useLiveFrame();
  return (
    <Card style={{flex: "1 1 45%", padding: "15px 18px", height: 574}}>
      <SectionLabel
        kicker="RISK / MATRIX"
        title="风险不是清单，是坐标"
        right={"P = 概率 / I = 影响\n" + data.risks.length + " ACTIVE"}
      />

      <div style={{display: "flex", gap: 10, marginTop: 18}}>
        <div
          style={{
            display: "flex",
            flexDirection: "column",
            justifyContent: "space-between",
            height: 290,
            fontFamily: MONO,
            fontSize: 7.5,
            color: C.faint,
            textAlign: "right",
            paddingBottom: 22,
            width: 28,
          }}
        >
          <span>100</span>
          <span>50</span>
          <span>0</span>
        </div>
        <div style={{flex: 1, position: "relative"}}>
          <div
            style={{
              position: "relative",
              height: 290,
              border: `1px solid ${C.line}`,
              background:
                "linear-gradient(135deg, rgba(255,90,90,0.06), rgba(255,200,87,0.035) 50%, rgba(85,242,210,0.025))",
            }}
          >
            <div style={{position: "absolute", left: "50%", top: 0, bottom: 0, width: 1, background: "rgba(255,255,255,0.07)"}} />
            <div style={{position: "absolute", left: 0, right: 0, top: "50%", height: 1, background: "rgba(255,255,255,0.07)"}} />
            <div
              style={{
                position: "absolute",
                right: 8,
                top: 7,
                fontFamily: MONO,
                fontSize: 7,
                color: C.red,
                opacity: 0.6,
                letterSpacing: 1,
              }}
            >
              HIGH / HIGH
            </div>
            <div
              style={{
                position: "absolute",
                left: 8,
                bottom: 7,
                fontFamily: MONO,
                fontSize: 7,
                color: C.cyan,
                opacity: 0.6,
                letterSpacing: 1,
              }}
            >
              LOW / LOW
            </div>

            {data.risks.map((r, i) => {
              const color = levelColor(r.level);
              return (
                <div
                  key={r.name}
                  style={{
                    position: "absolute",
                    left: `${r.i}%`,
                    bottom: `${r.p}%`,
                    width: 18,
                    height: 18,
                    transform: "translate(-50%, 50%)",
                    ...scaleIn(frame, 18 + i * 5, 30),
                  }}
                >
                  <div
                    style={{
                      position: "absolute",
                      inset: 0,
                      borderRadius: 99,
                      border: `1px solid ${color}`,
                      background: `${color}22`,
                      boxShadow: `0 0 14px ${color}66`,
                    }}
                  />
                  <div
                    style={{
                      position: "absolute",
                      inset: 0,
                      display: "flex",
                      alignItems: "center",
                      justifyContent: "center",
                      fontFamily: MONO,
                      fontSize: 8,
                      color,
                    }}
                  >
                    {i + 1}
                  </div>
                </div>
              );
            })}
          </div>
          <div
            style={{
              display: "flex",
              justifyContent: "space-between",
              fontFamily: MONO,
              fontSize: 7.5,
              color: C.faint,
              marginTop: 5,
            }}
          >
            <span>0 / IMPACT</span>
            <span>50</span>
            <span>100</span>
          </div>
          <div
            style={{
              position: "absolute",
              left: -34,
              top: 135,
              transform: "rotate(-90deg)",
              fontFamily: MONO,
              fontSize: 7.5,
              color: C.faint,
              letterSpacing: 1.2,
              whiteSpace: "nowrap",
            }}
          >
            PROBABILITY
          </div>
        </div>
      </div>

      <div style={{marginTop: 14}}>
        {data.risks.map((r, i) => (
          <div
            key={r.name}
            style={{
              display: "flex",
              alignItems: "center",
              gap: 8,
              height: 22,
              borderTop: i === 0 ? "none" : `1px solid rgba(255,255,255,0.045)`,
            }}
          >
            <span style={{fontFamily: MONO, fontSize: 8, color: levelColor(r.level), width: 12}}>
              {String(i + 1).padStart(2, "0")}
            </span>
            <span style={{fontSize: 9.5, color: C.text, width: 92}}>{r.name}</span>
            <span style={{fontSize: 8, color: C.faint, flex: 1}}>{r.mitigation}</span>
            <span
              style={{
                fontFamily: MONO,
                fontSize: 7,
                color: levelColor(r.level),
                border: `1px solid ${levelColor(r.level)}44`,
                padding: "1px 4px",
              }}
            >
              {r.level.toUpperCase()}
            </span>
          </div>
        ))}
      </div>
    </Card>
  );
};

const Decisions = ({data}) => {
  const frame = useLiveFrame();
  const dense = data.decisions.length > 10;
  return (
    <Card style={{flex: "1 1 27%", padding: "15px 16px", height: 574}}>
      <SectionLabel kicker="DECISIONS / ADR" title="已拍板" right={data.decisions.length + " RECORDS\nFROZEN"} />
      <div style={{marginTop: dense ? 8 : 12}}>
        {data.decisions.map((d, i) => (
          <div
            key={d.id}
            style={{
              padding: dense ? "4px 0 3px" : "7px 0 6px",
              borderTop: i === 0 ? "none" : `1px solid rgba(255,255,255,0.045)`,
              ...enter(frame, 20 + i * 3, 8, 16),
            }}
          >
            <div style={{display: "flex", gap: 7, alignItems: "baseline"}}>
              <span style={{fontFamily: MONO, fontSize: dense ? 7.5 : 8, color: C.cyan, width: 20}}>
                {d.id}
              </span>
              <span style={{fontSize: dense ? 9 : 10, color: C.text, lineHeight: 1.3, flex: 1}}>
                {d.text}
              </span>
            </div>
            <div style={{marginLeft: 27, marginTop: dense ? 1 : 2, fontSize: dense ? 7.2 : 8, color: C.faint, lineHeight: 1.28}}>
              {d.why}
            </div>
          </div>
        ))}
      </div>
    </Card>
  );
};

const Changelog = ({data}) => {
  const frame = useLiveFrame();
  return (
    <Card style={{flex: "1 1 28%", padding: "15px 16px", height: 574}} accent={C.amber}>
      <SectionLabel
        kicker="CHANGELOG / LIVE"
        title="更新记录"
        right={`${data.changelog.length} ENTRIES\nSINGLE SOURCE`}
      />
      <div style={{position: "relative", marginTop: 14}}>
        <div
          style={{
            position: "absolute",
            left: 4,
            top: 4,
            bottom: 0,
            width: 1,
            background: `linear-gradient(180deg, ${C.amber}66, transparent)`,
          }}
        />
        {data.changelog.slice(0, 9).map((c, i) => (
          <div
            key={`${c.date}-${c.tag}`}
            style={{
              position: "relative",
              paddingLeft: 18,
              paddingBottom: 11,
              ...enter(frame, 22 + i * 6, 8, 16),
            }}
          >
            <div
              style={{
                position: "absolute",
                left: 0,
                top: 4,
                width: 9,
                height: 9,
                background: i === 0 ? C.amber : C.bg,
                border: `1px solid ${i === 0 ? C.amber : C.faint}`,
                transform: "rotate(45deg)",
              }}
            />
            <div style={{display: "flex", gap: 7, alignItems: "center"}}>
              <span style={{fontFamily: MONO, fontSize: 7.5, color: C.faint}}>{c.date}</span>
              <span
                style={{
                  fontFamily: MONO,
                  fontSize: 7,
                  color: i === 0 ? C.amber : C.cyan,
                  border: `1px solid ${(i === 0 ? C.amber : C.cyan)}33`,
                  padding: "1px 4px",
                }}
              >
                {c.tag}
              </span>
            </div>
            <div style={{marginTop: 3, fontSize: 8.5, lineHeight: 1.4, color: C.dim}}>
              {c.text}
            </div>
          </div>
        ))}
        {data.changelog.length > 9 ? (
          <div style={{marginTop: 2, paddingLeft: 18, fontFamily: MONO, fontSize: 7.5, color: C.faint}}>
            +{data.changelog.length - 9} 条更早记录见 HTML 页下方
          </div>
        ) : null}
      </div>

    </Card>
  );
};

const NextGate = ({data}) => {
  const frame = useLiveFrame();
  return (
    <Card
      style={{
        height: 110,
        padding: "12px 16px",
        display: "flex",
        alignItems: "center",
        gap: 18,
        ...enter(frame, 48, 14, 18),
      }}
    >
      <div style={{width: 170, flex: "0 0 auto"}}>
        <div style={{fontFamily: MONO, fontSize: 8, letterSpacing: 1.8, color: C.amber}}>
          NEXT GATE / W2
        </div>
        <div style={{fontSize: 16, fontWeight: 700, color: C.white, marginTop: 4}}>
          真人试玩
        </div>
        <div style={{fontSize: 8.5, color: C.faint, marginTop: 3}}>
          0/1 通关 · 第一优先
        </div>
      </div>
      <div style={{display: "flex", gap: 8, flex: 1}}>
        {data.nextGate.map((g, i) => (
          <div
            key={g}
            style={{
              flex: 1,
              minWidth: 0,
              borderLeft: `1px solid ${C.line}`,
              paddingLeft: 9,
              ...enter(frame, 52 + i * 4, 8, 14),
            }}
          >
            <div style={{fontFamily: MONO, fontSize: 7.5, color: C.cyan}}>
              0{i + 1}
            </div>
            <div style={{fontSize: 8.5, lineHeight: 1.4, color: C.dim, marginTop: 3}}>
              {g}
            </div>
          </div>
        ))}
      </div>
    </Card>
  );
};

export const Risk = ({data}) => {
  return (
    <Frame chapter="RISK / LOG" index={4} total={4} title="风险与日志" data={data}>
      <div style={{display: "flex", flexDirection: "column", gap: 12, height: "100%"}}>
        <div style={{display: "flex", gap: 12, height: 574}}>
          <RiskMatrix data={data} />
          <Decisions data={data} />
          <Changelog data={data} />
        </div>
        <NextGate data={data} />
      </div>
    </Frame>
  );
};
