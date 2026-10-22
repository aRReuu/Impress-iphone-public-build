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
  if (!["mermaid", "markmap", "impress-canvas", "impress-excalidraw"].includes(info)) {
    return originalFence(tokens, index, options, env, self);
  }
  const source = tokens[index].content || "";
  if (source.length > 950000 || diagrams.length >= 24) {
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


const svgNS = "http://www.w3.org/2000/svg";
function svgMake(parent, tag, attrs = {}, text = null) {
  const el = document.createElementNS(svgNS, tag);
  for (const [key,value] of Object.entries(attrs)) el.setAttribute(key, String(value));
  if (text !== null) el.textContent = String(text);
  parent.append(el);
  return el;
}
function unpack(encoded) {
  if (encoded.length > 950000 || !/^[A-Za-z0-9+/=\s]+$/.test(encoded))
    throw Error("Embedded data too large");
  return JSON.parse(new TextDecoder("utf-8", { fatal: true }).decode(
    Uint8Array.from(atob(encoded.trim()), (c) => c.charCodeAt(0))));
}
const val = (v, d = 0) => Number.isFinite(Number(v)) ? Number(v) : d;
const safeColor = (v,d="#62626a") => /^#[0-9a-fA-F]{6}$/.test(String(v || "")) ? v : d;
function diagramFrame(host, list) {
  const minx=Math.min(...list.map(e=>e.x)), miny=Math.min(...list.map(e=>e.y));
  const maxx=Math.max(...list.map(e=>e.x+e.w)), maxy=Math.max(...list.map(e=>e.y+e.h));
  const width=maxx-minx+64, height=maxy-miny+64;
  if (![width,height].every(Number.isFinite) || width>12000 || height>12000 ||
      width*height>20000000) throw Error("Invalid composite geometry");
  host.replaceChildren();
  const svg=svgMake(host,"svg",{viewBox:"0 0 "+width+" "+height,
    width:"100%",height:Math.max(240,Math.min(650,height)),
    role:"img","aria-label":"授权文件的只读图形预览"});
  return {svg,dx:32-minx,dy:32-miny};
}
function textAt(svg,x,y,content,width) {
  const letters=String(content || "").slice(0,1400);
  const chars=Math.max(6,Math.min(50,Math.floor(width/12)));
  const chunks=letters.split("\n").flatMap(line=>{
    const parts=[];
    for(let i=0;i<line.length;i+=chars)parts.push(line.slice(i,i+chars));
    return parts.length?parts:[""];
  }).slice(0,18);
  const text=svgMake(svg,"text",{x,y,"font-size":15,fill:"currentColor",
    "font-family":"-apple-system,system-ui,sans-serif"});
  for(const [idx,line] of chunks.entries())
    svgMake(text,"tspan",{x,dy:idx?19:0},line);
  svgMake(text,"title",{},letters);
}
function drawNativeGeometry(host,encoded,kind) {
  const data=unpack(encoded);
  const isCanvas=kind==="impress-canvas";
  const raw=isCanvas?data.nodes:data.elements;
  const edges=isCanvas?(data.edges || []):[];
  if(!Array.isArray(raw)||raw.length===0||raw.length>350||edges.length>600)
    throw Error("Composite limits exceeded");
  const list=raw.filter(e=>!e.isDeleted).map(e=>({raw:e,x:val(e.x),y:val(e.y),
    w:Math.max(1,val(e.width,1)),h:Math.max(1,val(e.height,1))}));
  if(!list.length)throw Error("Empty drawing");
  const {svg,dx,dy}=diagramFrame(host,list);
  if(isCanvas) {
    const nodes=new Map(list.map(e=>[e.raw.id,e]));
    for(const edge of edges) {
      const a=nodes.get(edge.fromNode),b=nodes.get(edge.toNode);
      if(!a||!b)continue;
      const sx=a.x+a.w+dx,sy=a.y+a.h/2+dy,ex=b.x+dx,ey=b.y+b.h/2+dy;
      svgMake(svg,"path",{d:"M"+sx+" "+sy+" C"+(sx+24)+" "+sy+" "+(ex-24)+" "+ey+" "+ex+" "+ey,
        fill:"none",stroke:safeColor(edge.color,"#888890"),"stroke-width":2});
    }
  }
  for(const e of list) {
    const n=e.raw,x=e.x+dx,y=e.y+dy,w=e.w,h=e.h;
    const color=safeColor(isCanvas?n.color:n.strokeColor);
    const attrs={stroke:color,"stroke-width":isCanvas?1.6:Math.min(20,Math.max(0.5,val(n.strokeWidth,1.5))),
      fill:safeColor(n.backgroundColor,"transparent")};
    let shape;
    if(n.type==="ellipse")shape=svgMake(svg,"ellipse",{cx:x+w/2,cy:y+h/2,rx:w/2,ry:h/2,...attrs});
    else if(n.type==="diamond")shape=svgMake(svg,"polygon",{points:(x+w/2)+","+y+" "+(x+w)+","+(y+h/2)+" "+(x+w/2)+","+(y+h)+" "+x+","+(y+h/2),...attrs});
    else if(["line","arrow","freedraw"].includes(n.type)&&Array.isArray(n.points)) {
      const pts=n.points.slice(0,1200).filter(p=>Array.isArray(p)&&p.length>=2)
        .map(p=>(x+val(p[0]))+","+(y+val(p[1]))).join(" ");
      shape=svgMake(svg,"polyline",{points:pts,fill:"none",stroke:color,"stroke-width":attrs["stroke-width"]});
    } else if(n.type!=="text")shape=svgMake(svg,"rect",{x,y,width:w,height:h,rx:4,...attrs,
      "stroke-dasharray":n.type==="group"?"7 5":"none"});
    if(shape&&!isCanvas&&Number.isFinite(Number(n.angle)))
      shape.setAttribute("transform","rotate("+(val(n.angle)*180/Math.PI)+" "+(x+w/2)+" "+(y+h/2)+")");
    if(n.type==="text"||isCanvas)
      textAt(svg,x+8,y+20,n.text||n.label||n.file||n.url||"",w-16);
    if(n.type==="image")textAt(svg,x+6,y+21,"图像在独立图纸页查看",w-12);
  }
}

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
  const fontSize = Math.max(12, Math.min(42, Number(options?.fontSize) || 17));
  style.textContent = String(options?.css || "") +
    "\n.markdown-body{font-size:" + fontSize + "px!important;}";
  root.innerHTML = markdown.render(plain);
  const firstHeading = root.firstElementChild;
  if (firstHeading?.tagName === "H1" && String(options?.documentTitle || "").trim() ===
      firstHeading.textContent.trim()) {
    firstHeading.hidden = true; // Native document title already expresses this H1.
  }
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
      } else if (spec.kind === "markmap") {
        await drawMarkmap(container, spec.source);
      } else {
        drawNativeGeometry(container, spec.source, spec.kind);
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
