import React from "react";
import {interpolate} from "remotion";
import {useLiveFrame} from "../live/LiveClock";
import {C, MONO} from "../theme";
import {Frame} from "../components/Frame";
import {Card, Chip, SectionLabel} from "../components/UI";
import {enter, progress, pulse} from "../components/anim";

const SyncPanel = ({parry, start}) => {
  const frame = useLiveFrame();
  const fill = progress(frame, start, 64) * 0.62;
  const marker = 62;
  return (
    <Card style={{flex: "1 1 58%", padding: "16px 20px", height: 360}}>
      <SectionLabel
        kicker="DUAL CONSCIOUSNESS / SYNC"
        title="同步率：在跷跷板上跳舞"
        right={"0 = 阿针\n100 = 阿绫"}
      />

      <div style={{display: "flex", alignItems: "flex-end", gap: 10, marginTop: 16}}>
        <span
          style={{
            fontFamily: MONO,
            fontSize: 72,
            lineHeight: 0.9,
            fontWeight: 700,
            color: C.cyan,
            textShadow: `0 0 28px ${C.cyan}44`,
          }}
        >
          {Math.round(fill * 100)}
        </span>
        <span style={{fontFamily: MONO, fontSize: 13, color: C.faint, marginBottom: 6}}>
          / 100
        </span>
        <div style={{flex: 1}} />
        <Chip color={C.pink}>接管阈值 100</Chip>
      </div>

      <div style={{marginTop: 18, position: "relative", height: 36}}>
        <div
          style={{
            position: "absolute",
            left: 0,
            right: 0,
            top: 15,
            height: 8,
            background:
              "linear-gradient(90deg, rgba(85,242,210,0.26), rgba(255,200,87,0.26) 62%, rgba(255,61,127,0.26))",
          }}
        >
          <div
            style={{
              width: `${fill * 100}%`,
              height: "100%",
              background: "linear-gradient(90deg, #2bb7a4, #55f2d2 55%, #ffc857)",
              boxShadow: `0 0 16px ${C.cyan}55`,
            }}
          />
        </div>
        {Array.from({length: 11}, (_, i) => (
          <div
            key={i}
            style={{
              position: "absolute",
              left: `${(i / 10) * 100}%`,
              top: 27,
              width: 1,
              height: i % 5 === 0 ? 10 : 5,
              background: "rgba(232,243,255,0.22)",
            }}
          />
        ))}
        <div
          style={{
            position: "absolute",
            left: `${marker}%`,
            top: 0,
            width: 1,
            height: 34,
            background: C.amber,
            opacity: 0.28,
            borderLeft: `1px dashed ${C.amber}`,
          }}
        />
        <div
          style={{
            position: "absolute",
            left: `calc(${marker}% - 4px)`,
            top: 10,
            width: 9,
            height: 18,
            background: C.amber,
            boxShadow: `0 0 14px ${C.amber}aa`,
            opacity: 0.72 + 0.24 * pulse(frame, 7),
          }}
        />
      </div>

      <div
        style={{
          display: "flex",
          justifyContent: "space-between",
          fontFamily: MONO,
          fontSize: 8.5,
          color: C.faint,
          letterSpacing: 1,
          marginTop: 2,
        }}
      >
        <span>0 / 阿针 · 稳</span>
        <span>50 / 临界</span>
        <span>100 / 阿绫 · 接管</span>
      </div>

      <div style={{display: "flex", gap: 10, marginTop: 20}}>
        {[
          {k: "接管持续", v: `${parry.takeoverSeconds}s`, c: C.pink},
          {k: "接管后回", v: "50", c: C.amber},
          {k: "完整度代价", v: `-${parry.integrityCost}`, c: C.red},
        ].map((x) => (
          <div
            key={x.k}
            style={{
              flex: 1,
              border: `1px solid ${C.line}`,
              padding: "8px 10px",
              background: "rgba(255,255,255,0.018)",
            }}
          >
            <div style={{fontFamily: MONO, fontSize: 8, color: C.faint, letterSpacing: 0.8}}>
              {x.k}
            </div>
            <div style={{marginTop: 3, fontFamily: MONO, fontSize: 18, color: x.c}}>
              {x.v}
            </div>
          </div>
        ))}
      </div>

      <div
        style={{
          marginTop: 14,
          fontFamily: MONO,
          fontSize: 8.5,
          letterSpacing: 0.7,
          color: C.dim,
          lineHeight: 1.6,
        }}
      >
        阿针：控场 / 修复 / 稳 <span style={{color: C.faint}}>·</span>{" "}
        阿绫：爆发 / 故障 / 玻璃大炮
        <br />
        满 100：阿绫强制接管 8 秒，完整度 -20
      </div>
    </Card>
  );
};

const ParryPanel = ({parry, start}) => {
  const frame = useLiveFrame();
  const draw = progress(frame, start + 8, 56);
  const perfectW = (parry.perfect / parry.cooldown) * 100;
  const activeW = ((parry.active - parry.perfect) / parry.cooldown) * 100;
  const lateW = 100 - perfectW - activeW;
  return (
    <Card style={{flex: "1 1 42%", padding: "16px 20px", height: 360}} accent={C.pink}>
      <SectionLabel
        kicker="SEAM PARRY / TIMING"
        title="接住敌人的接缝"
        right={"LIGHT PRESS\n0.20s WINDOW"}
      />

      <div style={{marginTop: 24, position: "relative", height: 92}}>
        <div
          style={{
            position: "absolute",
            left: 0,
            right: 0,
            top: 35,
            height: 20,
            display: "flex",
            background: "rgba(255,255,255,0.04)",
          }}
        >
          <div style={{width: `${perfectW * draw}%`, background: C.cyan, boxShadow: `0 0 18px ${C.cyan}88`}} />
          <div style={{width: `${activeW * draw}%`, background: C.amber, opacity: 0.78}} />
          <div style={{width: `${lateW * draw}%`, background: "rgba(255,90,90,0.26)"}} />
        </div>

        <div style={{position: "absolute", left: 0, top: 16, fontFamily: MONO, fontSize: 9, color: C.cyan}}>
          PERFECT
        </div>
        <div
          style={{
            position: "absolute",
            left: `${perfectW}%`,
            top: 16,
            transform: "translateX(-50%)",
            fontFamily: MONO,
            fontSize: 9,
            color: C.amber,
          }}
        >
          ACTIVE
        </div>
        <div
          style={{
            position: "absolute",
            right: 0,
            top: 16,
            fontFamily: MONO,
            fontSize: 9,
            color: C.red,
          }}
        >
          LATE
        </div>

        {[
          {x: 0, label: "0.00"},
          {x: perfectW, label: "0.08"},
          {x: perfectW + activeW, label: "0.20"},
          {x: 100, label: "0.40"},
        ].map((m) => (
          <div
            key={m.label}
            style={{
              position: "absolute",
              left: `${m.x}%`,
              top: 58,
              width: 1,
              height: 11,
              background: "rgba(232,243,255,0.32)",
            }}
          />
        ))}
        <div
          style={{
            position: "absolute",
            left: "2%",
            top: 29,
            width: 2,
            height: 32,
            background: C.white,
            boxShadow: `0 0 12px ${C.white}`,
            opacity: 0.5 + 0.5 * pulse(frame, 6),
          }}
        />
      </div>

      <div
        style={{
          display: "flex",
          justifyContent: "space-between",
          fontFamily: MONO,
          fontSize: 8.5,
          color: C.faint,
          marginTop: 4,
        }}
      >
        <span>0.00</span>
        <span style={{color: C.cyan}}>完美 0.08s</span>
        <span style={{color: C.amber}}>普通 0.20s</span>
        <span style={{color: C.red}}>冷却 0.40s</span>
      </div>

      <div style={{display: "grid", gridTemplateColumns: "1fr 1fr", gap: 8, marginTop: 20}}>
        {[
          ["+6", "同步率 / 普通弹反"],
          ["+50%", "完美后伤害"],
          ["0.6s", "自动换人"],
          ["1.5s", "接缝暴露"],
        ].map(([v, k]) => (
          <div
            key={k}
            style={{
              border: `1px solid ${C.line}`,
              padding: "8px 10px",
              background: "rgba(255,255,255,0.018)",
            }}
          >
            <div style={{fontFamily: MONO, fontSize: 19, color: C.cyan}}>{v}</div>
            <div style={{fontSize: 8.5, color: C.faint, marginTop: 2}}>{k}</div>
          </div>
        ))}
      </div>

      <div
        style={{
          marginTop: 11,
          fontFamily: MONO,
          fontSize: 8,
          color: C.dim,
          letterSpacing: 0.7,
        }}
      >
        输入缓冲 0.15s · 完美返还冷却 · 红招不可弹
      </div>
    </Card>
  );
};

export const Combat = ({data}) => {
  const frame = useLiveFrame();
  return (
    <Frame chapter="COMBAT" index={3} total={4} title="战斗" data={data}>
      <div style={{display: "flex", flexDirection: "column", gap: 14, height: "100%"}}>
        <div style={{display: "flex", justifyContent: "space-between", alignItems: "flex-end"}}>
          <SectionLabel
            kicker="SYSTEM / FEEL"
            title="双意识不是姿态，是风险"
            right={"NO HEALTH BAR\nINTEGRITY ONLY"}
          />
          <div style={{display: "flex", gap: 6}}>
            <Chip color={C.cyan}>完美 0.08s</Chip>
            <Chip color={C.amber}>普通 0.20s</Chip>
            <Chip color={C.pink}>M</Chip>
          </div>
        </div>

        <div style={{display: "flex", gap: 14, height: 360}}>
          <SyncPanel parry={data.parry} start={12} />
          <ParryPanel parry={data.parry} start={18} />
        </div>

        <div style={{display: "flex", gap: 10, flex: 1, minHeight: 0}}>
          {[
            {
              k: "PERFECT PARRY",
              title: "完美弹反 = 换人",
              lines: ["自动切阿绫 0.6s", "同步冻结 2s", "接缝暴露 1.5s"],
              color: C.cyan,
            },
            {
              k: "INTEGRITY",
              title: "没有血条，只有完整度",
              lines: ["归零 = 断线", "检查点 = 针眼", "接管代价 -20"],
              color: C.pink,
            },
            {
              k: "DUAL FORM",
              title: "切得越狠，反噬越近",
              lines: ["阿针：控场 / 修复", "阿绫：爆发 / 故障", "同步率会说话"],
              color: C.amber,
            },
          ].map((c, i) => (
            <Card
              key={c.k}
              accent={c.color}
              style={{
                position: "relative",
                overflow: "hidden",
                flex: 1,
                padding: "13px 15px",
                ...enter(frame, 48 + i * 6, 16, 20),
              }}
            >
              <div style={{fontFamily: MONO, fontSize: 8, letterSpacing: 1.6, color: c.color}}>
                {c.k}
              </div>
              <div style={{fontSize: 14, fontWeight: 650, color: C.text, marginTop: 5}}>
                {c.title}
              </div>
              {c.lines.map((l) => (
                <div
                  key={l}
                  style={{
                    marginTop: 5,
                    fontSize: 9,
                    color: C.dim,
                    display: "flex",
                    gap: 6,
                    alignItems: "center",
                  }}
                >
                  <span style={{width: 3, height: 3, background: c.color, borderRadius: 99}} />
                  {l}
                </div>
              ))}
              <div
                style={{
                  position: "absolute",
                  right: 12,
                  bottom: -10,
                  fontFamily: MONO,
                  fontSize: 92,
                  fontWeight: 700,
                  lineHeight: 1,
                  color: c.color,
                  opacity: 0.08,
                }}
              >
                0{i + 1}
              </div>
              <div
                style={{
                  position: "absolute",
                  right: 15,
                  bottom: 12,
                  left: 15,
                  height: 1,
                  background: `linear-gradient(90deg, ${c.color}55, transparent)`,
                }}
              />
            </Card>
          ))}
        </div>
      </div>
    </Frame>
  );
};
