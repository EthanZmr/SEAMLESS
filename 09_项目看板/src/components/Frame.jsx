import React from "react";
import {interpolate} from "remotion";
import {Background} from "./Background";
import {useLiveFrame} from "../live/LiveClock";
import {C, FONT, MONO} from "../theme";
import {enter} from "./anim";

const Mark = () => (
  <svg width="34" height="34" viewBox="0 0 34 34" style={{flex: "0 0 auto"}}>
    <rect x="1" y="1" width="32" height="32" fill="none" stroke={C.cyan} strokeOpacity="0.55" />
    <path d="M9 3 V31" stroke={C.cyan} strokeWidth="1" strokeDasharray="2 4" />
    <path d="M17 8 H27 M17 17 H24 M17 26 H29" stroke={C.cyan} strokeWidth="1" opacity="0.72" />
    <circle cx="9" cy="17" r="2.2" fill={C.amber} />
  </svg>
);

export const Header = ({chapter, index, total, title, data}) => {
  const frame = useLiveFrame();
  const lineWidth = interpolate(frame, [0, 34], [0, 1472], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  return (
    <header
      style={{
        position: "absolute",
        top: 26,
        left: 64,
        right: 64,
        height: 48,
        display: "flex",
        alignItems: "center",
        gap: 18,
        fontFamily: FONT,
        color: C.text,
        ...enter(frame, 0, 12, 18),
      }}
    >
      <Mark />
      <div style={{display: "flex", flexDirection: "column", gap: 2}}>
        <div style={{fontSize: 19, fontWeight: 700, letterSpacing: 2}}>无缝</div>
        <div
          style={{
            fontFamily: MONO,
            fontSize: 10,
            letterSpacing: 2.4,
            color: C.dim,
          }}
        >
          SEAMLESS / PROJECT OS
        </div>
      </div>

      <div style={{width: 1, height: 30, background: C.line, marginLeft: 8}} />

      <div style={{display: "flex", flexDirection: "column", gap: 2}}>
        <div
          style={{
            fontFamily: MONO,
            fontSize: 10.5,
            letterSpacing: 2,
            color: C.cyan,
          }}
        >
          {chapter} / {String(index).padStart(2, "0")}–{String(total).padStart(2, "0")}
        </div>
        <div style={{fontSize: 15.5, fontWeight: 600, letterSpacing: 1}}>{title}</div>
      </div>

      <div style={{flex: 1}} />

      <div style={{display: "flex", alignItems: "center", gap: 10}}>
        <span
          style={{
            width: 6,
            height: 6,
            borderRadius: 99,
            background: C.green,
            boxShadow: `0 0 10px ${C.green}`,
          }}
        />
        <span style={{fontSize: 12.5, color: C.green, letterSpacing: 1.2}}>
          {data.meta.stage}
        </span>
      </div>
      <div style={{width: 1, height: 26, background: C.line, margin: "0 4px"}} />
      <div
        style={{
          fontFamily: MONO,
          fontSize: 11.5,
          color: C.dim,
          letterSpacing: 1.2,
          textAlign: "right",
          lineHeight: 1.6,
        }}
      >
        <div>
          {data.meta.week} / {data.meta.weeks} WEEKS
        </div>
        <div style={{color: C.faint}}>{data.meta.updated}</div>
      </div>

      <div
        style={{
          position: "absolute",
          left: 0,
          bottom: -1,
          width: lineWidth,
          height: 1,
          background: `linear-gradient(90deg, ${C.cyan}, rgba(85,242,210,0.05))`,
        }}
      />
    </header>
  );
};

export const Footer = ({index, total, data}) => {
  const frame = useLiveFrame();
  return (
    <footer
      style={{
        position: "absolute",
        left: 64,
        right: 64,
        bottom: 22,
        height: 22,
        display: "flex",
        alignItems: "center",
        fontFamily: MONO,
        fontSize: 10.5,
        letterSpacing: 1.1,
        color: C.faint,
        opacity: interpolate(frame, [18, 38], [0, 1], {
          extrapolateLeft: "clamp",
          extrapolateRight: "clamp",
        }),
      }}
    >
      <div>DATA SOURCE / {data.meta.build}</div>
      <div style={{flex: 1, textAlign: "center", color: "rgba(85,242,210,0.45)"}}>
        REAL OUTPUT ONLY / NO FABRICATION
      </div>
      <div>
        CHAPTER {String(index).padStart(2, "0")} / {String(total).padStart(2, "0")}
      </div>
    </footer>
  );
};

export const Frame = ({children, chapter, index, total, title, data}) => {
  return (
    <div style={{position: "relative", width: 1600, height: 900, overflow: "hidden", backgroundColor: C.bg, fontFamily: FONT}}>
      <Background />
      <Header
        chapter={chapter}
        index={index}
        total={total}
        title={title}
        data={data}
      />
      <div style={{position: "absolute", left: 64, right: 64, top: 92, bottom: 58}}>
        {children}
      </div>
      <Footer index={index} total={total} data={data} />
    </div>
  );
};
