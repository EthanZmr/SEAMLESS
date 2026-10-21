import React, {useMemo} from "react";
import {useLiveFrame} from "../live/LiveClock";
import {C} from "../theme";

const makeDrops = (count) =>
  Array.from({length: count}, (_, i) => {
    const seed = ((i * 9301 + 49297) % 233280) / 233280;
    const seed2 = ((i * 4177 + 12345) % 233280) / 233280;
    return {
      x: seed * 100,
      offset: seed2,
      speed: 2.2 + seed2 * 5.6,
      length: 18 + seed * 54,
      opacity: 0.12 + seed2 * 0.34,
      pink: i % 7 === 0,
    };
  });

const TICKS = Array.from({length: 31}, (_, i) => i);

export const Background = ({intensity = 1}) => {
  const frame = useLiveFrame();
  const drops = useMemo(() => makeDrops(52), []);
  const scan = (frame * 5) % 940;

  return (
    <div style={{position: "absolute", inset: 0, backgroundColor: C.bg, overflow: "hidden"}}>
      <div
        style={{position: "absolute", inset: 0,
          background:
            "radial-gradient(1000px 620px at 16% 6%, rgba(30,128,142,0.20), transparent 62%), radial-gradient(760px 520px at 88% 24%, rgba(255,61,127,0.12), transparent 64%), linear-gradient(158deg, #04070e 0%, #07101d 48%, #04070e 100%)",
        }}
      />
      <div
        style={{position: "absolute", inset: 0,
          opacity: 0.42 * intensity,
          backgroundImage:
            "linear-gradient(rgba(96,198,196,0.075) 1px, transparent 1px), linear-gradient(90deg, rgba(96,198,196,0.075) 1px, transparent 1px)",
          backgroundSize: "64px 64px",
          maskImage:
            "radial-gradient(ellipse at 50% 42%, black 20%, transparent 78%)",
          WebkitMaskImage:
            "radial-gradient(ellipse at 50% 42%, black 20%, transparent 78%)",
        }}
      />

      <svg
        width="100%"
        height="100%"
        viewBox="0 0 1600 900"
        style={{position: "absolute", inset: 0, opacity: 0.9}}
      >
        <line
          x1="30"
          y1="-20"
          x2="30"
          y2="920"
          stroke={C.cyan}
          strokeWidth="1"
          strokeDasharray="2 12"
          strokeDashoffset={-frame * 0.55}
          opacity="0.36"
        />
        <line
          x1="1570"
          y1="-20"
          x2="1570"
          y2="920"
          stroke={C.pink}
          strokeWidth="1"
          strokeDasharray="2 16"
          strokeDashoffset={frame * 0.4}
          opacity="0.24"
        />
        {TICKS.map((i) => (
          <line
            key={i}
            x1={i % 2 === 0 ? 24 : 27}
            y1={i * 31}
            x2={i % 2 === 0 ? 36 : 33}
            y2={i * 31}
            stroke={C.cyan}
            strokeWidth="1"
            opacity={0.18 + (i % 5) * 0.035}
          />
        ))}
      </svg>

      {drops.map((d, i) => {
        const y = ((d.offset * 980 + frame * d.speed) % 980) - 60;
        return (
          <div
            key={i}
            style={{
              position: "absolute",
              left: `${d.x}%`,
              top: y,
              width: 1,
              height: d.length,
              opacity: d.opacity * intensity,
              background: `linear-gradient(180deg, transparent, ${
                d.pink ? C.pink : C.cyan
              })`,
              boxShadow: d.pink
                ? `0 0 6px ${C.pink}`
                : `0 0 5px ${C.cyan}`,
            }}
          />
        );
      })}

      <div
        style={{
          position: "absolute",
          left: 0,
          right: 0,
          top: scan,
          height: 1,
          background:
            "linear-gradient(90deg, transparent, rgba(120,255,238,0.22), transparent)",
          opacity: 0.5,
        }}
      />

      <div
        style={{position: "absolute", inset: 0,
          background:
            "radial-gradient(ellipse at center, transparent 42%, rgba(0,0,0,0.52) 100%)",
        }}
      />
      <div
        style={{position: "absolute", inset: 0,
          opacity: 0.055,
          backgroundImage:
            "repeating-linear-gradient(0deg, #fff 0px, #fff 1px, transparent 1px, transparent 4px)",
          mixBlendMode: "overlay",
        }}
      />
    </div>
  );
};
