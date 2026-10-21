import React, {useEffect, useRef, useState} from "react";
import {createRoot} from "react-dom/client";
import data from "./data/project.json";
import {Overview} from "./chapters/Overview.jsx";
import {Pipeline} from "./chapters/Pipeline.jsx";
import {Combat} from "./chapters/Combat.jsx";
import {Risk} from "./chapters/Risk.jsx";
import {LiveClockProvider} from "./live/LiveClock.jsx";

const CHAPTERS = [
  {
    id: "overview",
    label: "总览",
    en: "STATUS",
    component: Overview,
    duration: 360,
    desc: "项目坐标、里程碑、范围与 W1 真实测试结果。",
  },
  {
    id: "pipeline",
    label: "流程",
    en: "PIPELINE",
    component: Pipeline,
    duration: 360,
    desc: "玩家 30 秒循环、雨市 A–F 路径、裁断者三阶段与战后选择。",
  },
  {
    id: "combat",
    label: "战斗",
    en: "COMBAT",
    component: Combat,
    duration: 330,
    desc: "同步率、完整度、0.08 秒完美弹反与自动换人。",
  },
  {
    id: "risk",
    label: "风险与日志",
    en: "RISK / LOG",
    component: Risk,
    duration: 390,
    desc: "风险坐标、七条已拍板决策、更新记录与 W2 门禁。",
  },
];

class Boundary extends React.Component {
  constructor(props) {
    super(props);
    this.state = {error: null};
  }

  static getDerivedStateFromError(error) {
    return {error};
  }

  componentDidCatch(error, info) {
    console.error("Dashboard render failed", error, info);
  }

  render() {
    if (this.state.error) {
      return (
        <div className="fatal">
          <div className="fatal-kicker">DASHBOARD ERROR</div>
          <h2>看板渲染失败</h2>
          <pre>{String(this.state.error.message || this.state.error)}</pre>
          <p>检查浏览器控制台，或重新运行构建脚本。</p>
        </div>
      );
    }
    return this.props.children;
  }
}

const StatusDot = ({color = "green"}) => (
  <span className={`status-dot ${color}`} aria-hidden="true" />
);

const Topbar = ({tab, onTab}) => (
  <header className="topbar">
    <div className="brand">
      <svg className="brand-mark" viewBox="0 0 34 34" aria-hidden="true">
        <rect x="1" y="1" width="32" height="32" />
        <path d="M9 3 V31" className="dash" />
        <path d="M17 8 H27 M17 17 H24 M17 26 H29" />
        <circle cx="9" cy="17" r="2.2" />
      </svg>
      <div>
        <div className="brand-cn">无缝</div>
        <div className="brand-en">SEAMLESS / PROJECT OS</div>
      </div>
    </div>

    <nav className="nav" aria-label="章节">
      {CHAPTERS.map((c, i) => (
        <button
          key={c.id}
          className={`nav-btn ${tab === c.id ? "active" : ""}`}
          onClick={() => onTab(c.id)}
        >
          <span className="nav-index">0{i + 1}</span>
          <span>{c.label}</span>
          <span className="nav-en">{c.en}</span>
        </button>
      ))}
    </nav>

    <div className="top-status">
      <StatusDot />
      <span>{data.meta.stage}</span>
      <span className="top-sep" />
      <span className="mono">{data.meta.week} / {data.meta.weeks}W</span>
    </div>
  </header>
);

const MissionBar = () => (
  <section className="mission-bar" aria-label="任务状态">
    <div className="mission-id">
      <div className="mission-kicker mono">MISSION CONTROL / 01</div>
      <div className="mission-line">
        <strong>{data.meta.week}</strong>
        <span className="mono">/ {data.meta.weeks} WEEKS</span>
        <em>{data.meta.next}</em>
      </div>
      <div className="mission-meta">
        M · SOLO · {data.meta.engine} · {data.meta.platform}
      </div>
    </div>

    <div className="mission-metrics">
      <span><b>{data.kpis[0].value}</b>断言</span>
      <span><b className="green">{data.kpis[2].value}</b>阻断</span>
      <span><b className="red">0/1</b>真人</span>
    </div>

    <div className="mission-links">
      <a href="../../00_项目看板.md" target="_blank" rel="noreferrer">项目看板 ↗</a>
      <a href="../../05_游戏工程/README.md" target="_blank" rel="noreferrer">工程 README ↗</a>
      <a href="../../06_测试/02_测试报告_W1.md" target="_blank" rel="noreferrer">W1 报告 ↗</a>
    </div>
  </section>
);

const LiveBoard = ({chapter, replayKey, boardRef, onFullscreen}) => {
  const wrapRef = useRef(null);
  const [scale, setScale] = useState(1);

  useEffect(() => {
    const el = wrapRef.current;
    if (!el) return undefined;
    const measure = () => setScale(Math.max(0.1, el.clientWidth / 1600));
    measure();
    const observer = new ResizeObserver(measure);
    observer.observe(el);
    return () => observer.disconnect();
  }, []);

  const Chapter = chapter.component;

  return (
    <div
      className="live-board"
      ref={(node) => {
        wrapRef.current = node;
        if (boardRef) boardRef.current = node;
      }}
      style={{height: 900 * scale}}
      onDoubleClick={onFullscreen}
    >
      <div
        className="live-board-canvas"
        style={{
          width: 1600,
          height: 900,
          transform: `scale(${scale})`,
        }}
      >
        <LiveClockProvider key={replayKey} duration={chapter.duration}>
          <Chapter data={data} />
        </LiveClockProvider>
      </div>
    </div>
  );
};

const LiveStage = ({tab, onTab, replayKey, onReplay}) => {
  const chapter = CHAPTERS.find((c) => c.id === tab) || CHAPTERS[0];
  const index = CHAPTERS.indexOf(chapter) + 1;
  const boardRef = useRef(null);

  const toggleFullscreen = () => {
    const el = boardRef.current;
    if (!el) return;
    if (document.fullscreenElement) {
      document.exitFullscreen?.();
    } else {
      el.requestFullscreen?.();
    }
  };

  return (
    <section className="stage" aria-label="项目动效看板">
      <div className="stage-head">
        <div>
          <div className="mono cyan stage-kicker">LIVE MOTION / DOM / 30 FPS</div>
          <h2>
            {chapter.label}
            <span className="stage-en">{chapter.en}</span>
          </h2>
        </div>
        <div className="stage-meta mono">
          <span className="live"><StatusDot /> LIVE</span>
          <span>CHAPTER {String(index).padStart(2, "0")} / 0{CHAPTERS.length}</span>
          <span className="fs-hint">双击全屏</span>
        </div>
      </div>

      <LiveBoard
        chapter={chapter}
        replayKey={replayKey}
        boardRef={boardRef}
        onFullscreen={toggleFullscreen}
      />
      <div className="live-board-mobile mono">
        动效看板在 ≥ 900px 屏幕显示 · 下方数据完整可读
      </div>

      <div className="stage-foot">
        <p>{chapter.desc}</p>
        <div className="stage-actions">
          <button className="ghost-btn" onClick={onReplay}>
            ↻ 重播动效
          </button>
          <button className="ghost-btn" onClick={toggleFullscreen}>
            ⛶ 全屏看板
          </button>
          <button
            className="ghost-btn"
            onClick={() => {
              const next = CHAPTERS[(index % CHAPTERS.length)];
              onTab(next.id);
            }}
          >
            下一章 →
          </button>
        </div>
      </div>
    </section>
  );
};

const KpiStrip = () => (
  <section className="kpi-strip" aria-label="项目数据">
    {data.kpis.map((k) => (
      <div className={`stat-card ${k.tone}`} key={k.label}>
        <div className="stat-value">
          {k.value}
          <span>{k.suffix}</span>
        </div>
        <div className="stat-label">{k.label}</div>
        <div className="stat-hint">{k.hint}</div>
      </div>
    ))}
  </section>
);

const Scope = () => (
  <section className="scope-grid" aria-label="范围冻结">
    <div className="panel scope-card s0">
      <div className="panel-label">S0 / MUST SHIP</div>
      <h3>这次 17 周只做这些</h3>
      <ul>
        {data.scope.s0.map((x) => (
          <li key={x}>{x}</li>
        ))}
      </ul>
      <div className="scope-tag">FROZEN</div>
    </div>
    <div className="panel scope-card s1">
      <div className="panel-label">S1 / AFTER SLICE</div>
      <h3>切片通过后再说</h3>
      <ul>
        {data.scope.s1.map((x) => (
          <li key={x}>{x}</li>
        ))}
      </ul>
      <div className="scope-tag">DEFERRED</div>
    </div>
    <div className="panel scope-card s2">
      <div className="panel-label">S2 / CUT</div>
      <h3>明确不做</h3>
      <ul>
        {data.scope.s2.map((x) => (
          <li key={x}>{x}</li>
        ))}
      </ul>
      <div className="scope-tag">CUT</div>
    </div>
  </section>
);

const Milestones = () => (
  <section className="panel lower-panel" aria-label="里程碑">
    <div className="panel-head">
      <div>
        <div className="panel-label">MILESTONE RAIL</div>
        <h3>17 周交付路径</h3>
      </div>
      <span className="mono muted">1 / 6 COMPLETE</span>
    </div>
    <div className="milestone-list">
      {data.milestones.map((m) => (
        <div className={`milestone-row ${m.status}`} key={m.id}>
          <span className="ms-id">{m.id}</span>
          <span className="ms-dot" />
          <div className="ms-main">
            <div>
              {m.name} <span className="mono muted">{m.weeks}</span>
            </div>
            <div className="ms-gate">{m.gate}</div>
          </div>
          <span className="ms-status">{m.status}</span>
        </div>
      ))}
    </div>
  </section>
);

const Log = () => (
  <section className="panel lower-panel" aria-label="更新记录">
    <div className="panel-head">
      <div>
        <div className="panel-label">CHANGELOG / SINGLE SOURCE</div>
        <h3>更新记录</h3>
      </div>
      <span className="mono muted">{data.changelog.length} ENTRIES</span>
    </div>
    <div className="log-list">
      {data.changelog.map((c) => (
        <div className="log-row" key={`${c.date}-${c.tag}`}>
          <div className="log-date mono">{c.date}</div>
          <span className="log-tag">{c.tag}</span>
          <p>{c.text}</p>
        </div>
      ))}
    </div>
    <div className="update-note">
      后续更新：编辑 <code>src/data/project.json</code>，运行 <code>node scripts/build.mjs</code>，刷新本页。
    </div>
  </section>
);

const Gate = () => (
  <section className="panel gate-panel" aria-label="下一道门禁">
    <div className="panel-head">
      <div>
        <div className="panel-label">NEXT GATE / W2</div>
        <h3>真人试玩 · 第一优先</h3>
      </div>
      <span className="gate-warning mono">0 / 1 HUMAN RUN</span>
    </div>
    <div className="gate-list">
      {data.nextGate.map((g, i) => (
        <div key={g}>
          <span className="mono cyan">0{i + 1}</span>
          <span>{g}</span>
        </div>
      ))}
    </div>
  </section>
);

const App = () => {
  const [tab, setTab] = useState("overview");
  const [replayKey, setReplayKey] = useState(0);

  const onTab = (id) => {
    setTab(id);
    setReplayKey((k) => k + 1);
  };

  return (
    <Boundary>
      <div className="app">
        <div className="page-ambient" aria-hidden="true" />
        <Topbar tab={tab} onTab={onTab} />
        <main className="shell">
          <MissionBar />
          <LiveStage
            tab={tab}
            onTab={onTab}
            replayKey={replayKey}
            onReplay={() => setReplayKey((k) => k + 1)}
          />
        </main>

        <KpiStrip />
        <Scope />
        <div className="lower-grid">
          <Milestones />
          <Log />
        </div>
        <Gate />

        <footer className="page-footer">
          <span>《无缝》SEAMLESS · 垂直切片项目看板</span>
          <span className="mono">
            DATA / src/data/project.json · UPDATED {data.meta.updated}
          </span>
        </footer>
      </div>
    </Boundary>
  );
};

createRoot(document.getElementById("root")).render(<App />);
