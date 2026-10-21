export const C = {
  bg: "#04070e",
  bg2: "#07101d",
  panel: "rgba(8, 19, 34, 0.78)",
  panelSolid: "#081322",
  line: "rgba(105, 224, 214, 0.18)",
  lineStrong: "rgba(105, 224, 214, 0.46)",
  text: "#e8f3ff",
  dim: "#7f97ae",
  faint: "#4d6278",
  cyan: "#55f2d2",
  cyanSoft: "#2bb7a4",
  amber: "#ffc857",
  pink: "#ff3d7f",
  red: "#ff5a5a",
  green: "#7dffa8",
  blue: "#6aa8ff",
  white: "#f5fbff",
};

export const FONT =
  '"Microsoft YaHei UI", "Microsoft YaHei", "PingFang SC", "Noto Sans SC", sans-serif';

export const MONO =
  '"Cascadia Mono", "JetBrains Mono", "SFMono-Regular", Consolas, monospace';

export const toneColor = (tone) => {
  if (tone === "amber") return C.amber;
  if (tone === "pink") return C.pink;
  if (tone === "green") return C.green;
  if (tone === "red") return C.red;
  if (tone === "blue") return C.blue;
  return C.cyan;
};
