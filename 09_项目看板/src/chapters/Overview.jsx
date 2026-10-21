import React from "react";
import {interpolate} from "remotion";
import {useLiveFrame} from "../live/LiveClock";
import {C, FONT, MONO} from "../theme";
import {Frame} from "../components/Frame";
import {
  Bar,
  BuildCard,
  Card,
  Chip,
  KpiCard,
  MilestoneRail,
  SectionLabel,
  SprintCard,
} from "../components/UI";
import {enter} from "../components/anim";
import prologue from "../../assets/prologue.png";

const TestPanel = ({tests, start}) => {
  const frame = useLiveFrame();
  return (
    <Card
      style={{
        padding: "15px 18px 12px",
        height: 238,
        ...enter(frame, start, 18, 24),
      }}
    >
      <SectionLabel
        kicker="TEST GATES / REAL OUTPUT"
        title="W1 验证"
        right={`${tests.total} ASSERTIONS\n0 FAIL`}
      />
      <div style={{marginTop: 6}}>
        <Bar
          label={tests.logic.label}
          pass={tests.logic.pass}
          total={tests.logic.total}
          note={tests.logic.note}
          start={start + 8}
        />
        <Bar
          label={tests.integration.label}
          pass={tests.integration.pass}
          total={tests.integration.total}
          note={tests.integration.note}
          start={start + 14}
        />
        <Bar
          label={tests.headless.label}
          pass={tests.headless.pass}
          total={tests.headless.total}
          note={tests.headless.note}
          start={start + 20}
        />
        <Bar
          label={tests.human.label}
          pass={tests.human.pass}
          total={tests.human.total}
          note={tests.human.note}
          start={start + 26}
          danger
        />
      </div>
    </Card>
  );
};

export const Overview = ({data}) => {
  const frame = useLiveFrame();
  const glitch = Math.sin(frame / 8) * 1.2;

  return (
    <Frame
      chapter="STATUS"
      index={1}
      total={4}
      title="总览"
      data={data}
    >
      <div style={{display: "flex", flexDirection: "column", gap: 14, height: "100%"}}>
        <div style={{display: "flex", gap: 26, height: 342}}>
          <div style={{flex: "1 1 68%", minWidth: 0, paddingTop: 4}}>
            <div
              style={{
                ...enter(frame, 2, 10, 18),
                fontFamily: MONO,
                fontSize: 9,
                letterSpacing: 2.6,
                color: C.cyan,
              }}
            >
              VERTICAL SLICE / 25–30 MIN / M
            </div>
            <div style={{position: "relative", marginTop: 5, height: 138}}>
              <div
                style={{
                  position: "absolute",
                  left: glitch * 2.5,
                  top: 2,
                  fontSize: 94,
                  lineHeight: 1,
                  fontWeight: 800,
                  letterSpacing: 2,
                  color: "rgba(255,61,127,0.22)",
                  filter: "blur(1px)",
                  ...enter(frame, 3, 16, 20),
                }}
              >
                无缝
              </div>
              <div
                style={{
                  position: "absolute",
                  left: 2,
                  top: 0,
                  fontSize: 94,
                  lineHeight: 1,
                  fontWeight: 800,
                  letterSpacing: 2,
                  color: C.white,
                  textShadow: `0 0 38px ${C.cyan}44`,
                  ...enter(frame, 4, 18, 22),
                }}
              >
                无缝
              </div>
              <div
                style={{
                  position: "absolute",
                  left: 5,
                  top: 100,
                  fontFamily: MONO,
                  fontSize: 23,
                  letterSpacing: 15,
                  color: C.cyan,
                  opacity: 0.9,
                  ...enter(frame, 10, 10, 20),
                }}
              >
                SEAMLESS
              </div>
            </div>

            <div
              style={{
                marginTop: 7,
                fontSize: 17,
                lineHeight: 1.55,
                color: C.text,
                letterSpacing: 0.8,
                ...enter(frame, 16, 16, 22),
              }}
            >
              {data.meta.tagline}
            </div>
            <div
              style={{
                marginTop: 5,
                fontSize: 10,
                color: C.dim,
                letterSpacing: 1.4,
                ...enter(frame, 20, 10, 20),
              }}
            >
              {data.meta.subtagline} · 一个人，一座城，两个意识
            </div>

            <div style={{display: "flex", gap: 6, marginTop: 16, ...enter(frame, 24, 10, 20)}}>
              <Chip color={C.pink}>RATING {data.meta.rating}</Chip>
              <Chip color={C.cyan}>{data.meta.engine}</Chip>
              <Chip color={C.amber}>TEAM {data.meta.team}</Chip>
              <Chip color={C.blue}>PC / ITCH</Chip>
            </div>
          </div>

          <div style={{flex: "1 1 32%", display: "flex", flexDirection: "column", gap: 12}}>
            <BuildCard
              image={prologue}
              tag="W1 BUILD / 序章实机"
              title="地下诊所，雨夜"
              caption="34 条对白 · 可跳过 · 已接入标题与雨市"
              style={{height: 210}}
            />
            <SprintCard data={data} style={{flex: 1}} />
          </div>
        </div>

        <div style={{display: "flex", gap: 10, height: 94}}>
          {data.kpis.map((k, i) => (
            <KpiCard key={k.label} item={k} start={26 + i * 6} index={i} />
          ))}
        </div>

        <div style={{display: "flex", gap: 16, flex: 1, minHeight: 0}}>
          <div style={{flex: "1 1 66%", minWidth: 0}}>
            <MilestoneRail milestones={data.milestones} start={42} />
          </div>
          <div style={{flex: "1 1 34%", minWidth: 0}}>
            <TestPanel tests={data.tests} start={44} />
          </div>
        </div>
      </div>
    </Frame>
  );
};
