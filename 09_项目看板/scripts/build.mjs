import fs from "node:fs";
import path from "node:path";
import {fileURLToPath, pathToFileURL} from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(__dirname, "..");
const DIST = path.join(ROOT, "dist");
const SRC = path.join(ROOT, "src");

const runtimeCandidates = [
  process.env.REMOTION_RUNTIME,
  "C:/Users/Administrator/.dsh/data/dsh-remotion/runtime",
  path.resolve(ROOT, "../../../.dsh/data/dsh-remotion/runtime"),
].filter(Boolean);

const RUNTIME = runtimeCandidates.find((dir) =>
  fs.existsSync(path.join(dir, "node_modules", "esbuild", "lib", "main.js")),
);

if (!RUNTIME) {
  throw new Error(
    "找不到 dsh-remotion 运行时。请设置 REMOTION_RUNTIME 指向包含 node_modules 的 runtime 目录。",
  );
}

const NM = path.join(RUNTIME, "node_modules");
const {build, transform} = await import(
  pathToFileURL(path.join(NM, "esbuild", "lib", "main.js")).href
);

const aliases = new Map([
  ["@remotion/player", path.join(NM, "@remotion", "player", "dist", "esm", "index.mjs")],
  ["remotion/no-react", path.join(NM, "remotion", "dist", "esm", "no-react.mjs")],
  ["remotion", path.join(NM, "remotion", "dist", "esm", "index.mjs")],
  ["react-dom/client", path.join(NM, "react-dom", "client.js")],
  ["react-dom", path.join(NM, "react-dom", "index.js")],
  ["react/jsx-runtime", path.join(NM, "react", "jsx-runtime.js")],
  ["react", path.join(NM, "react", "index.js")],
]);

const aliasPlugin = {
  name: "dsh-remotion-runtime",
  setup(pluginBuild) {
    pluginBuild.onResolve({filter: /.*/}, (args) => {
      if (aliases.has(args.path)) {
        return {path: aliases.get(args.path)};
      }
      return undefined;
    });
  },
};

const template = fs.readFileSync(path.join(ROOT, "index.template.html"), "utf8");
const cssSource = fs.readFileSync(path.join(SRC, "styles.css"), "utf8");
const css = (await transform(cssSource, {loader: "css", minify: true})).code;

const result = await build({
  entryPoints: [path.join(SRC, "main.jsx")],
  bundle: true,
  write: false,
  format: "iife",
  platform: "browser",
  target: ["chrome100", "edge100", "firefox100", "safari15"],
  jsx: "automatic",
  loader: {".json": "json", ".png": "dataurl", ".jpg": "dataurl", ".svg": "dataurl"},
  define: {"process.env.NODE_ENV": '"production"'},
  minify: true,
  legalComments: "none",
  plugins: [aliasPlugin],
  logLevel: "warning",
});

const js = result.outputFiles[0].text.replace(/<\/script/gi, "<\\/script");
const html = template
  .replace("__DASHBOARD_CSS__", css)
  .replace("__DASHBOARD_JS__", js);

fs.mkdirSync(DIST, {recursive: true});
fs.writeFileSync(path.join(DIST, "index.html"), html, "utf8");

const assetsSrc = path.join(ROOT, "assets");
const assetsDst = path.join(DIST, "assets");
if (fs.existsSync(assetsSrc)) {
  fs.mkdirSync(assetsDst, {recursive: true});
  for (const name of fs.readdirSync(assetsSrc)) {
    const dest = path.join(assetsDst, name);
    if (fs.existsSync(dest)) {
      fs.rmSync(dest, {force: true});
    }
    fs.copyFileSync(path.join(assetsSrc, name), dest);
    fs.chmodSync(dest, 0o644);
  }
}

const manifest = {
  name: "无缝 SEAMLESS · 项目看板",
  version: "1.2.0",
  builtAt: new Date().toISOString(),
  entry: "index.html",
  bytes: Buffer.byteLength(html, "utf8"),
  assets: fs.existsSync(assetsDst)
    ? fs.readdirSync(assetsDst).map((name) => ({
        name,
        bytes: fs.statSync(path.join(assetsDst, name)).size,
      }))
    : [],
};
fs.writeFileSync(
  path.join(DIST, "manifest.json"),
  `${JSON.stringify(manifest, null, 2)}\n`,
  "utf8",
);

console.log(`\n无缝 SEAMLESS · 项目看板构建完成`);
console.log(`  dist/index.html  ${(manifest.bytes / 1024).toFixed(1)} KB`);
console.log(`  assets           ${manifest.assets.length} 个`);
console.log(`  runtime          ${RUNTIME}`);
console.log(`  builtAt          ${manifest.builtAt}\n`);
