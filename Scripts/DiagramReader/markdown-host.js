import MarkdownIt from "markdown-it";
import mermaid from "mermaid";
import { Transformer } from "markmap-lib";
import { Markmap } from "markmap-view";

const root = document.getElementById("reader");
const style = document.getElementById("impress-reading-css");
const markdown = new MarkdownIt({ html: false, linkify: false, breaks: true, typographer: false });
const escapeHtml = (input) => markdown.utils.escapeHtml(String(input || ""));
const sanitizeDiagram = (source) => String(source || "")
  .replace(/%%\{[\s\S]*?\}%%/g, "")
  .replace(/^\s*click\s+.*$/gm, "");
const cleanText = (source) => String(source || "")
  .replaceAll("&", "&amp;").replaceAll("<", "&lt;").replaceAll(">", "&gt;");
const diagrams = [];
let serial = 0;
let liveMaps = [];
const report = (state, diagramCount, failures) => {
  window.webkit?.messageHandlers?.markdownState?.postMessage({
    state, diagramCount, failures
  });
};

const originalFence = markdown.renderer.rules.fence ||
  ((tokens, index, options, env, self) => self.renderToken(tokens, index, options));
markdown.renderer.rules.fence = (tokens, index, options, env, self) => {
  const info = (tokens[index].info || "").trim().split(/\s+/)[0].toLowerCase();
  if (info !== "mermaid" && info !== "markmap") {
    return originalFence(tokens, index, options, env, self);
  }
  const source = tokens[index].content || "";
  if (source.length > 200000 || diagrams.length >= 24) {
    return "<aside class=\"im-diagram-error\">图形超出离线阅读限制，请查看源码。</aside>";
  }
  const indexInDocument = diagrams.push({ kind: info, source }) - 1;
  return "<section class=\"im-diagram " + info + "\" data-im-index=\"" +
    indexInDocument + "\" aria-label=\"" + info + " 离线图形\"><p>图形加载中…</p></section>";
};

const originalImage = markdown.renderer.rules.image ||
  ((tokens, idx, options, env, self) => self.renderToken(tokens, idx, options));
markdown.renderer.rules.image = (tokens, idx, options, env, self) => {
  const url = tokens[idx].attrGet("src") || "";
  if (!/^data:image\/jpeg;base64,[A-Za-z0-9+/=]{1,650000}$/.test(url)) {
    return "<span class=\"im-diagram-error\">（图片被安全策略阻止）</span>";
  }
  return originalImage(tokens, idx, options, env, self);
};

function markTasks() {
  for (const li of root.querySelectorAll("li")) {
    const direct = li.querySelector(":scope > p") || li;
    const child = Array.from(direct.childNodes).find((node) => node.nodeType === Node.TEXT_NODE &&
      node.textContent.trim().length > 0);
    if (!child) continue;
    const match = child.textContent.match(/^\s*\[([ xX])\]\s*/);
    if (!match) continue;
    child.textContent = child.textContent.slice(match[0].length);
    const input = document.createElement("input");
    input.type = "checkbox";
    input.disabled = true;
    input.className = "im-task";
    input.checked = match[1].toLowerCase() === "x";
    input.setAttribute("aria-label", input.checked ? "已完成任务" : "待办任务");
    direct.insertBefore(input, direct.firstChild);
  }
}
function removeLinks(container) {
  for (const link of container.querySelectorAll("a")) {
    const label = document.createElement("span");
    label.textContent = link.textContent || "";
    link.replaceWith(label);
  }
}
async function drawMermaid(container, source, dark, id) {
  mermaid.initialize({
    startOnLoad: false, securityLevel: "strict", theme: dark ? "dark" : "default",
    suppressErrorRendering: true, maxTextSize: 200000,
    flowchart: { htmlLabels: false, useMaxWidth: false }
  });
  const result = await mermaid.render("im-read-graph-" + id, sanitizeDiagram(source));
  container.replaceChildren();
  const mount = document.createElement("div");
  mount.innerHTML = result.svg;
  removeLinks(mount);
  container.append(mount);
}
async function drawMarkmap(container, source) {
  const transformer = new Transformer();
  const transformed = transformer.transform(cleanText(source));
  const svg = document.createElementNS("http://www.w3.org/2000/svg", "svg");
  container.replaceChildren(svg);
  const map = Markmap.create(svg, { duration: 0, autoFit: true, maxWidth: 280 },
    transformed.root);
  liveMaps.push(map);
  if (map?.fit) await map.fit();
  removeLinks(container);
}

window.renderImpressMarkdown = async (body, options) => {
  const epoch = ++serial;
  const plain = String(body || "");
  if (plain.length > 8 * 1024 * 1024) {
    root.textContent = "文档超出阅读器安全预算，请切换到源码视图。";
    report("failed", 0, 1);
    return;
  }
  liveMaps.forEach((map) => {
    if (typeof map.destroy === "function") map.destroy();
  });
  liveMaps = [];
  diagrams.length = 0;
  style.textContent = String(options?.css || "");
  root.innerHTML = markdown.render(plain);
  markTasks();
  // Never make network requests for untrusted links or local Vault resources.
  // The native WKNavigationDelegate approves only explicit internal WikiLinks.
  const items = Array.from(root.querySelectorAll(".im-diagram[data-im-index]"));
  let failures = 0;
  for (let index = 0; index < items.length; index++) {
    if (epoch !== serial) return;
    const container = items[index];
    const spec = diagrams[Number(container.dataset.imIndex)];
    if (!spec) continue;
    try {
      if (spec.kind === "mermaid") {
        await drawMermaid(container, spec.source, !!options?.dark, epoch + "-" + index);
      } else {
        await drawMarkmap(container, spec.source);
      }
    } catch (error) {
      failures++;
      container.replaceChildren();
      const note = document.createElement("div");
      note.className = "im-diagram-error";
      note.textContent = "离线图形无法解析；其他正文不受影响。";
      const details = document.createElement("details");
      const summary = document.createElement("summary");
      summary.textContent = "查看当前图形源码";
      const code = document.createElement("pre");
      code.textContent = spec.source;
      details.append(summary, code);
      container.append(note, details);
    }
  }
  if (epoch === serial) {
    report(failures ? "partial" : "ready", items.length, failures);
  }
};
