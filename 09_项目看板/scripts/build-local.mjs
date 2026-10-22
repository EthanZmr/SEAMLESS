// 把 src/data/project.json 写进本地看板 local/index.html（单文件，双击即开）。
// 零依赖：只用 Node 自带模块，不需要 Remotion 运行时或 npm install。
//
// 用法：node 09_项目看板/scripts/build-local.mjs
import fs from "node:fs";
import path from "node:path";
import {fileURLToPath} from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const DATA = path.join(ROOT, "src", "data", "project.json");
const PAGE = path.join(ROOT, "local", "index.html");

const data = JSON.parse(fs.readFileSync(DATA, "utf8"));
// 内联进 <script> 时，"</" 会提前结束标签；转义成 "<\/"，JSON 语义不变。
const json = JSON.stringify(data).replace(/<\//g, "<\\/");

const html = fs.readFileSync(PAGE, "utf8");
const re = /(<script id="project-data" type="application\/json">)[\s\S]*?(<\/script>)/;
if (!re.test(html)) {
  console.error(`找不到数据块 <script id="project-data">：${PAGE}`);
  process.exit(1);
}
const out = html.replace(re, (_, open, close) => open + json + close);
if (out === html) {
  console.log("SKIP  local/index.html 已是最新");
} else {
  fs.writeFileSync(PAGE, out);
  console.log(`OK  ${path.relative(ROOT, DATA)} → ${path.relative(ROOT, PAGE)}（${data.changelog?.length ?? 0} 条更新记录）`);
}
