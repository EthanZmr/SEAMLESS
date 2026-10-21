import React from "react";
import {interpolate} from "remotion";
import {useLiveFrame} from "../live/LiveClock";
import {C, FONT, MONO, toneColor} from "../theme";
import {countUp, enter, progress, pulse, scaleIn} from "./anim";

export const Card = ({children, style, accent = C.cyan, className}) => (
  <div
    className={className}
    style={{
      position: "relative",
      background:
        "linear-gradient(155deg, rgba(10,24,42,0.92), rgba(5,12,23,0.88))",
      border: `1px solid ${C.line}`,
      boxShadow:
        "0 18px 50px rgba(0,0,0,0.28), inset 0 1px 0 rgba(255,255,255,0.035)",
      overflow: "hidden",
      ...style,
    }}
  >
    <div
      style={{
        position: "absolute",
        left: 0,
        top: 0,
        width: 44,
        height: 1,
        background: accent,
        opacity: 0.9,
      }}
    />
    <div
      style={{
        position: "absolute",
        right: 0,
        top: 0,
        width: 1,
        height: 26,
        background: accent,
        opacity: 0.45,
      }}
    />
    <div
      style={{
        position: "absolute",
        left: 0,
        bottom: 0,
        width: 1,
        height: 26,
        background: accent,
        opacity: 0.28,
      }}
    />
    {children}
  </div>
);

export const SectionLabel = ({kicker, title, right, style}) => (
  <div
    style={{
      display: "flex",
      alignItems: "flex-end",
      justifyContent: "space-between",
      gap: 20,
      ...style,
    }}
  >
    <div>
      <div
        style={{
          fontFamily: MONO,
          fontSize: 10.5,
          letterSpacing: 2.2,
          color: C.cyan,
          marginBottom: 4,
        }}
      >
        {kicker}
      </div>
      <div style={{fontSize: 21, fontWeight: 650, letterSpacing: 1.2, color: C.text}}>
        {title}
      </div>
    </div>
    {right ? (
      <div
        style={{
          fontFamily: MONO,
          fontSize: 10,
          letterSpacing: 1.4,
          color: C.faint,
          textAlign: "right",
          lineHeight: 1.6,
        }}
      >
        {right}
      </div>
    ) : null}
  </div>
);

export const Chip = ({children, color = C.cyan, style}) => (
  <span
    style={{
      display: "inline-flex",
      alignItems: "center",
      height: 24,
      padding: "0 9px",
      border: `1px solid ${color}44`,
      background: `${color}0d`,
      color,
      fontFamily: MONO,
      fontSize: 10,
      letterSpacing: 1.1,
      ...style,
    }}
  >
    {children}
  </span>
);

export const KpiCard = ({item, start, index, style}) => {
  const frame = useLiveFrame();
  const color = toneColor(item.tone);
  const value = countUp(frame, start, item.value);
  return (
    <Card
      accent={color}
      style={{
        flex: 1,
        height: 94,
        padding: "15px 18px 14px",
        ...enter(frame, start, 18, 22),
        ...style,
      }}
    >
      <div style={{display: "flex", alignItems: "baseline", gap: 4}}>
        <span
          style={{
            fontFamily: MONO,
            fontSize: 40,
            lineHeight: 1,
            fontWeight: 700,
            letterSpacing: -1,
            color: C.white,
            textShadow: `0 0 22px ${color}55`,
          }}
        >
          {value}
        </span>
        <span
          style={{
            fontSize: 12,
            color,
            fontFamily: MONO,
            letterSpacing: 0.6,
          }}
        >
          {item.suffix}
        </span>
      </div>
      <div style={{display: "flex", justifyContent: "space-between", marginTop: 8}}>
        <span style={{fontSize: 12.5, color: C.text, letterSpacing: 1}}>{item.label}</span>
        <span style={{fontSize: 10, color: C.faint, letterSpacing: 0.4}}>{item.hint}</span>
      </div>
      <div
        style={{
          position: "absolute",
          left: 18,
          right: 18,
          bottom: 0,
          height: 1,
          background: `linear-gradient(90deg, ${color}, transparent)`,
          opacity: 0.42,
        }}
      />
    </Card>
  );
};

export const Bar = ({label, pass, total, note, start, danger = false, color = C.cyan}) => {
  const frame = useLiveFrame();
  const p = progress(frame, start, 54);
  const ratio = total === 0 ? 0 : pass / total;
  const fill = ratio * p;
  const barColor = danger ? C.red : color;
  return (
    <div style={{marginBottom: 4}}>
      <div
        style={{
          display: "flex",
          alignItems: "baseline",
          justifyContent: "space-between",
          marginBottom: 3,
        }}
      >
        <span style={{fontSize: 12, color: C.text, letterSpacing: 0.8}}>{label}</span>
        <span style={{fontFamily: MONO, fontSize: 11, color: barColor}}>
          {pass} / {total}
        </span>
      </div>
      <div
        style={{
          height: 5,
          background: "rgba(255,255,255,0.055)",
          position: "relative",
          overflow: "hidden",
        }}
      >
        <div
          style={{
            position: "absolute",
            left: 0,
            top: 0,
            bottom: 0,
            width: `${fill * 100}%`,
            background: `linear-gradient(90deg, ${barColor}66, ${barColor})`,
            boxShadow: `0 0 12px ${barColor}55`,
          }}
        />
        <div
          style={{
            position: "absolute",
            inset: 0,
            backgroundImage:
              "repeating-linear-gradient(90deg, transparent 0 23px, rgba(0,0,0,0.45) 23px 24px)",
          }}
        />
      </div>
      <div style={{fontSize: 9.5, color: danger ? C.red : C.faint, marginTop: 4}}>
        {note}
      </div>
    </div>
  );
};

export const MilestoneRail = ({milestones, start}) => {
  const frame = useLiveFrame();
  const activeIndex = Math.max(
    0,
    milestones.findIndex((m) => m.status === "active")
  );
  const fill = progress(frame, start + 16, 56) * (activeIndex / (milestones.length - 1));
  return (
    <Card style={{padding: "16px 22px 14px", height: 238}}>
      <SectionLabel
        kicker="MILESTONE RAIL"
        title="17 周交付路径"
        right={`${milestones.filter((m) => m.status === "done").length} / ${
          milestones.length
        } COMPLETE`}
      />
      <div style={{position: "relative", height: 150, marginTop: 8}}>
        <div
          style={{
            position: "absolute",
            left: 54,
            right: 54,
            top: 40,
            height: 1,
            background: "rgba(120,190,205,0.17)",
          }}
        />
        <div
          style={{
            position: "absolute",
            left: 54,
            top: 40,
            height: 1,
            width: `calc((100% - 108px) * ${fill})`,
            background: `linear-gradient(90deg, ${C.cyan}, ${C.amber})`,
            boxShadow: `0 0 12px ${C.cyan}55`,
          }}
        />
        {milestones.map((m, i) => {
          const left = `calc(54px + (100% - 108px) * ${i / (milestones.length - 1)})`;
          const done = m.status === "done";
          const active = m.status === "active";
          const color = done ? C.cyan : active ? C.amber : C.faint;
          const nodeScale = scaleIn(frame, start + 8 + i * 7, 30);
          return (
            <div
              key={m.id}
              style={{
                position: "absolute",
                left,
                top: 22,
                width: 190,
                transform: "translateX(-50%)",
                textAlign: "center",
              }}
            >
              <div
                style={{
                  fontFamily: MONO,
                  fontSize: 10,
                  color,
                  letterSpacing: 1.3,
                  marginBottom: 4,
                }}
              >
                {m.id}
              </div>
              <div
                style={{
                  fontSize: 11,
                  color: done || active ? C.text : C.dim,
                  fontWeight: active ? 700 : 500,
                  letterSpacing: 0.6,
                  whiteSpace: "nowrap",
                }}
              >
                {m.name}
              </div>
              <div
                style={{
                  position: "relative",
                  width: 14,
                  height: 14,
                  margin: "8px auto 0",
                  ...nodeScale,
                }}
              >
                {active ? (
                  <div
                    style={{
                      position: "absolute",
                      inset: -7,
                      borderRadius: 99,
                      border: `1px solid ${C.amber}${Math.round(
                        55 + 70 * pulse(frame)
                      ).toString(16)}`,
                      boxShadow: `0 0 18px ${C.amber}55`,
                    }}
                  />
                ) : null}
                <div
                  style={{
                    width: 14,
                    height: 14,
                    borderRadius: 2,
                    background: done ? C.cyan : active ? C.amber : C.bg,
                    border: `1px solid ${color}`,
                    transform: "rotate(45deg)",
                    boxShadow: done || active ? `0 0 14px ${color}88` : "none",
                  }}
                />
              </div>
              <div
                style={{
                  marginTop: 8,
                  fontFamily: MONO,
                  fontSize: 9,
                  color: C.faint,
                  letterSpacing: 0.8,
                }}
              >
                {m.weeks}
              </div>
              <div
                style={{
                  marginTop: 3,
                  fontSize: 8.5,
                  color: active ? C.amber : C.faint,
                  lineHeight: 1.35,
                  maxWidth: 180,
                  marginLeft: "auto",
                  marginRight: "auto",
                }}
              >
                {m.gate}
              </div>
            </div>
          );
        })}
      </div>
    </Card>
  );
};

export const BuildCard = ({image, title, caption, tag, style}) => {
  const frame = useLiveFrame();
  return (
    <Card
      style={{
        padding: 0,
        ...enter(frame, 12, 24, 26),
        ...style,
      }}
    >
      <div style={{position: "relative", height: "100%", overflow: "hidden"}}>
        <img
          src={image}
          style={{
            width: "100%",
            height: "100%",
            objectFit: "cover",
            objectPosition: "center 54%",
            filter: "saturate(0.92) contrast(1.05) brightness(0.9)",
          }}
        />
        <div
          style={{
            position: "absolute",
            inset: 0,
            background:
              "linear-gradient(180deg, rgba(4,7,14,0.08), rgba(4,7,14,0.12) 38%, rgba(4,7,14,0.92))",
          }}
        />
        <div
          style={{
            position: "absolute",
            left: 14,
            top: 12,
            display: "flex",
            gap: 8,
            alignItems: "center",
          }}
        >
          <span
            style={{
              width: 5,
              height: 5,
              borderRadius: 99,
              background: C.green,
              boxShadow: `0 0 9px ${C.green}`,
            }}
          />
          <span
            style={{
              fontFamily: MONO,
              fontSize: 8.5,
              color: C.green,
              letterSpacing: 1.5,
            }}
          >
            {tag}
          </span>
        </div>
        <div style={{position: "absolute", left: 16, right: 16, bottom: 13}}>
          <div style={{fontSize: 16, fontWeight: 700, color: C.white, letterSpacing: 0.8}}>
            {title}
          </div>
          <div style={{fontSize: 11, color: C.dim, marginTop: 3, letterSpacing: 0.4}}>
            {caption}
          </div>
        </div>
      </div>
    </Card>
  );
};

export const SprintCard = ({data, style}) => {
  const frame = useLiveFrame();
  const total = data.meta.weeks;
  const current = 2;
  const ratio = current / total;
  const circumference = 2 * Math.PI * 48;
  const dash = circumference * ratio * progress(frame, 26, 50);
  return (
    <Card
      accent={C.amber}
      style={{padding: "15px 18px", display: "flex", gap: 16, ...enter(frame, 18, 20, 24), ...style}}
    >
      <div style={{position: "relative", width: 108, height: 108, flex: "0 0 auto"}}>
        <svg width="108" height="108" viewBox="0 0 108 108" style={{transform: "rotate(-90deg)"}}>
          <circle cx="54" cy="54" r="48" fill="none" stroke="rgba(255,255,255,0.06)" strokeWidth="5" />
          <circle
            cx="54"
            cy="54"
            r="48"
            fill="none"
            stroke={C.amber}
            strokeWidth="5"
            strokeLinecap="butt"
            strokeDasharray={`${dash} ${circumference}`}
            style={{filter: `drop-shadow(0 0 6px ${C.amber}66)`}}
          />
          <circle cx="54" cy="54" r="39" fill="none" stroke="rgba(255,200,87,0.13)" strokeWidth="1" strokeDasharray="2 6" />
        </svg>
        <div
          style={{
            position: "absolute",
            inset: 0,
            display: "flex",
            flexDirection: "column",
            alignItems: "center",
            justifyContent: "center",
          }}
        >
          <div
            style={{
              fontFamily: MONO,
              fontSize: 22,
              fontWeight: 700,
              color: C.amber,
              letterSpacing: -0.5,
            }}
          >
            {data.meta.week}
          </div>
          <div style={{fontFamily: MONO, fontSize: 8, color: C.faint, letterSpacing: 1}}>
            / {total} WEEKS
          </div>
        </div>
      </div>
      <div style={{flex: 1, minWidth: 0}}>
        <div
          style={{
            fontFamily: MONO,
            fontSize: 8.5,
            letterSpacing: 1.6,
            color: C.amber,
            marginBottom: 5,
          }}
        >
          CURRENT SPRINT
        </div>
        <div style={{fontSize: 19, fontWeight: 700, color: C.white, letterSpacing: 0.5}}>
          {data.meta.next}
        </div>
        <div style={{fontSize: 11, color: C.dim, marginTop: 6, lineHeight: 1.55}}>
          门禁：3/5 人主动二次尝试
          <br />
          3 分钟内有人出完美弹反
        </div>
        <div style={{display: "flex", gap: 5, marginTop: 9}}>
          <Chip color={C.amber} style={{height: 20, fontSize: 9}}>
            W2–4
          </Chip>
          <Chip color={C.cyan} style={{height: 20, fontSize: 9}}>
            1 人
          </Chip>
        </div>
      </div>
    </Card>
  );
};
