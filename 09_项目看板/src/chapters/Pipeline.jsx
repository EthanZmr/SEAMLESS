import React from "react";
import {useLiveFrame} from "../live/LiveClock";
import {C, MONO} from "../theme";
import {Frame} from "../components/Frame";
import {Card, Chip, SectionLabel} from "../components/UI";
import {enter, scaleIn} from "../components/anim";

const LoopNode = ({item, i, start, frame}) => {
  const color = i === 5 ? C.pink : i === 6 ? C.amber : C.cyan;
  return (
    <div
      style={{
        flex: 1,
        minWidth: 0,
        height: 104,
        position: "relative",
        padding: "10px 11px",
        background:
          "linear-gradient(170deg, rgba(11,26,45,0.9), rgba(5,12,22,0.82))",
        border: `1px solid ${i === 5 ? C.pink + "44" : C.line}`,
        ...enter(frame, start + i * 4, 14, 18),
      }}
    >
      <div
        style={{
          fontFamily: MONO,
          fontSize: 8,
          letterSpacing: 1.2,
          color,
          opacity: 0.85,
        }}
      >
        {item.n}
      </div>
      <div
        style={{
          marginTop: 6,
          fontSize: 11.5,
          fontWeight: 650,
          color: C.text,
          letterSpacing: 0.4,
          whiteSpace: "nowrap",
        }}
      >
        {item.label}
      </div>
      <div
        style={{
          marginTop: 4,
          fontSize: 8,
          lineHeight: 1.35,
          color: C.faint,
          letterSpacing: 0.2,
        }}
      >
        {item.note}
      </div>
      <div
        style={{
          position: "absolute",
          left: 11,
          bottom: 0,
          width: 22,
          height: 1,
          background: color,
          opacity: 0.7,
        }}
      />
    </div>
  );
};

const LevelCard = ({item, i, frame, start}) => {
  const color = item.id === "F" ? C.pink : item.id === "E" ? C.amber : C.cyan;
  return (
    <div
      style={{
        flex: 1,
        minWidth: 0,
        height: 178,
        position: "relative",
        padding: "13px 13px 12px",
        background:
          "linear-gradient(160deg, rgba(9,22,39,0.94), rgba(5,11,20,0.88))",
        border: `1px solid ${item.id === "F" ? C.pink + "55" : C.line}`,
        ...scaleIn(frame, start + i * 5, 30),
      }}
    >
      <div
        style={{
          display: "flex",
          justifyContent: "space-between",
          alignItems: "flex-start",
        }}
      >
        <span
          style={{
            fontFamily: MONO,
            fontSize: 38,
            lineHeight: 0.95,
            fontWeight: 700,
            color,
            opacity: 0.95,
            textShadow: `0 0 18px ${color}33`,
          }}
        >
          {item.id}
        </span>
        <span
          style={{
            fontFamily: MONO,
            fontSize: 7.5,
            letterSpacing: 1,
            color,
            border: `1px solid ${color}33`,
            padding: "2px 5px",
          }}
        >
          {item.tag}
        </span>
      </div>
      <div
        style={{
          marginTop: 16,
          fontSize: 13,
          fontWeight: 650,
          color: C.text,
          letterSpacing: 0.6,
        }}
      >
        {item.name}
      </div>
      <div style={{marginTop: 5, fontSize: 9, lineHeight: 1.45, color: C.dim}}>
        {item.note}
      </div>
      <div
        style={{
          position: "absolute",
          left: 13,
          right: 13,
          bottom: 10,
          height: 1,
          background: `linear-gradient(90deg, ${color}55, transparent)`,
        }}
      />
    </div>
  );
};

const Phase = ({p, i, frame, start}) => {
  const colors = [C.cyan, C.amber, C.pink];
  const color = colors[i] || C.cyan;
  return (
    <div
      style={{
        flex: 1,
        minWidth: 0,
        height: 158,
        padding: "12px 12px",
        background: "rgba(3,9,17,0.62)",
        border: `1px solid ${color}33`,
        ...enter(frame, start + i * 6, 14, 18),
      }}
    >
      <div style={{display: "flex", justifyContent: "space-between"}}>
        <span style={{fontFamily: MONO, fontSize: 9, color, letterSpacing: 1.2}}>
          {p.id}
        </span>
        <span style={{fontFamily: MONO, fontSize: 7.5, color: C.faint}}>
          {i === 2 ? "UNBLOCKABLE" : "PARRYABLE"}
        </span>
      </div>
      <div style={{marginTop: 10, fontSize: 15, fontWeight: 700, color: C.white}}>
        {p.name}
      </div>
      <div style={{marginTop: 5, fontSize: 9, lineHeight: 1.45, color: C.dim}}>
        {p.note}
      </div>
      <div
        style={{
          marginTop: 10,
          height: 4,
          background: "rgba(255,255,255,0.06)",
          position: "relative",
        }}
      >
        <div
          style={{
            position: "absolute",
            left: 0,
            top: 0,
            bottom: 0,
            width: `${34 + i * 22}%`,
            background: color,
            opacity: 0.75,
          }}
        />
      </div>
    </div>
  );
};

export const Pipeline = ({data}) => {
  const frame = useLiveFrame();

  return (
    <Frame chapter="PIPELINE" index={2} total={4} title="流程" data={data}>
      <div style={{display: "flex", flexDirection: "column", gap: 13, height: "100%"}}>
        <div style={{height: 170}}>
          <SectionLabel
            kicker="CORE LOOP / 30 SECONDS"
            title="玩家每 30 秒在做什么"
            right={"SCAN → STITCH → CUT\nSWITCH → OVERLOAD"}
          />
          <div style={{display: "flex", gap: 7, marginTop: 15}}>
            {data.loop.map((item, i) => (
              <LoopNode key={item.n} item={item} i={i} start={12} frame={frame} />
            ))}
          </div>
        </div>

        <div style={{height: 242}}>
          <SectionLabel
            kicker="RAIN MARKET / A–F"
            title="雨市：一条路，三种解法"
            right={"20–25 MIN\n3 SEAMS / 1 NEEDLE EYE"}
          />
          <div style={{display: "flex", gap: 9, marginTop: 14}}>
            {data.level.map((item, i) => (
              <LevelCard
                key={item.id}
                item={item}
                i={i}
                frame={frame}
                start={34}
              />
            ))}
          </div>
        </div>

        <Card
          style={{
            flex: 1,
            minHeight: 0,
            padding: "14px 16px",
            ...enter(frame, 52, 16, 20),
          }}
        >
          <div style={{display: "flex", justifyContent: "space-between"}}>
            <SectionLabel
              kicker="BOSS / THE TRIMMER"
              title="裁断者：把她的接缝，变成你的"
              right={"3 PHASES\n1 CHOICE"}
            />
            <div style={{display: "flex", gap: 6, alignItems: "flex-start"}}>
              <Chip color={C.pink}>25–30 MIN</Chip>
              <Chip color={C.amber}>M</Chip>
            </div>
          </div>

          <div style={{display: "flex", gap: 12, height: 158, marginTop: 12}}>
            <div style={{flex: "1 1 68%", display: "flex", gap: 8}}>
              {data.boss.phases.map((p, i) => (
                <Phase key={p.id} p={p} i={i} frame={frame} start={64} />
              ))}
            </div>
            <div
              style={{
                flex: "1 1 32%",
                borderLeft: `1px solid ${C.line}`,
                paddingLeft: 14,
                display: "flex",
                flexDirection: "column",
                justifyContent: "center",
                gap: 8,
              }}
            >
              <div
                style={{
                  fontFamily: MONO,
                  fontSize: 8.5,
                  letterSpacing: 1.8,
                  color: C.dim,
                }}
              >
                POST-BOSS / 二选一
              </div>
              {data.boss.choice.map((c, i) => (
                <div
                  key={c.label}
                  style={{
                    display: "flex",
                    alignItems: "center",
                    gap: 11,
                    border: `1px solid ${i === 0 ? C.pink + "44" : C.cyan + "44"}`,
                    background: i === 0 ? "rgba(255,61,127,0.06)" : "rgba(85,242,210,0.05)",
                    padding: "8px 10px",
                  }}
                >
                  <span
                    style={{
                      fontFamily: MONO,
                      fontSize: 22,
                      fontWeight: 700,
                      color: i === 0 ? C.pink : C.cyan,
                      width: 26,
                    }}
                  >
                    {c.label}
                  </span>
                  <div style={{flex: 1}}>
                    <div style={{fontSize: 9.5, color: C.text}}>{c.desc}</div>
                    <div
                      style={{
                        marginTop: 2,
                        fontFamily: MONO,
                        fontSize: 7.5,
                        color: C.faint,
                        letterSpacing: 0.8,
                      }}
                    >
                      {c.tag}
                    </div>
                  </div>
                </div>
              ))}
            </div>
          </div>
        </Card>
      </div>
    </Frame>
  );
};
