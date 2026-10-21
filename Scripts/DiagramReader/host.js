import mermaid from "mermaid";
import { Transformer } from "markmap-lib";
import { Markmap } from "markmap-view";

const viewport = document.getElementById("diagram");
const status = document.getElementById("status");
const safeText = (value) => String(value || "").replaceAll("&", "&amp;")
  .replaceAll("<", "&lt;").replaceAll(">", "&gt;");
let instance = null;

async function renderDiagram(request) {
  const kind = request?.kind;
  const raw = String(request?.source || "");
  if (!["mermaid", "markmap"].includes(kind) || raw.length > 200000) {
    throw new Error("Invalid local diagram scope");
  }
  viewport.replaceChildren();
  status.textContent = "";
  if (kind === "mermaid") {
    mermaid.initialize({
      startOnLoad: false, securityLevel: "strict", theme: request.dark ? "dark" : "default",
      suppressErrorRendering: true, maxTextSize: 200000,
      flowchart: { htmlLabels: false, useMaxWidth: false }
    });
    // Read-only screen projection: directives and click callbacks cannot
    // override the host's trusted renderer/security configuration.
    const sanitized = raw.replace(/%%\{[\s\S]*?\}%%/g, "")
      .replace(/^\s*click\s+.*$/gm, "");
    const result = await mermaid.render("impress-mermaid-" + Math.random().toString(36).slice(2),
      sanitized);
    const holder = document.createElement("div");
    holder.className = "mermaid-result";
    holder.innerHTML = result.svg;
    viewport.append(holder);
    viewport.querySelectorAll("a").forEach((link) => {
      const text = document.createElement("span");
      text.textContent = link.textContent;
      link.replaceWith(text);
    });
    return;
  }
  // Raw HTML is inert; the original Markdown bytes remain in the Vault.
  const transformer = new Transformer();
  const parsed = transformer.transform(safeText(raw));
  const svg = document.createElementNS("http://www.w3.org/2000/svg", "svg");
  svg.setAttribute("id", "mindmap");
  svg.setAttribute("width", "100%");
  svg.setAttribute("height", "100%");
  viewport.append(svg);
  if (instance && typeof instance.destroy === "function") instance.destroy();
  instance = Markmap.create(svg, { duration: 0, autoFit: true, maxWidth: 280 }, parsed.root);
  if (instance && typeof instance.fit === "function") await instance.fit();
}
window.renderImpressDiagram = (request) => {
  Promise.resolve().then(() => renderDiagram(request)).then(() => {
    status.textContent = "";
    window.webkit?.messageHandlers?.diagramState?.postMessage({ state: "ready" });
  }).catch((error) => {
    viewport.replaceChildren();
    status.textContent = "Diagram could not render safely: " + String(error?.message || "unknown");
    window.webkit?.messageHandlers?.diagramState?.postMessage({ state: "failed" });
  });
};