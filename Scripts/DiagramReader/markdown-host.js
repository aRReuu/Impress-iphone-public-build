import MarkdownIt from "markdown-it";
import katex from "katex";

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
let propertyDocumentKey = "";
let propertiesExpanded = true;

// Trusted, typed metadata only; no YAML/HTML is interpreted in the web page.
// The native bridge is responsible for all Vault identity/version checks.
function renderNativeDocumentHeader(options, currentEpoch) {
  const header = document.createElement("header");
  header.className = "im-document-header";
  const title = document.createElement("h1");
  title.className = "im-document-title";
  title.id = "impress.notes.document-title";
  title.textContent = String(options?.documentTitle || "");
  header.append(title);
  const rawFields = Array.isArray(options?.properties) ? options.properties : [];
  const fields = rawFields.slice(0, 128).filter(
    (field) => field && typeof field.name === "string" &&
      typeof field.value === "string");
  const diagnostic = String(options?.propertiesDiagnostic || "").slice(0, 320);
  const key = String(options?.documentKey || "");
  if (propertyDocumentKey !== key) {
    propertyDocumentKey = key;
    propertiesExpanded = true;
  }
  if (fields.length > 0) {
    const details = document.createElement("details");
    details.className = "im-properties";
    details.open = propertiesExpanded;
    const summary = document.createElement("summary");
    summary.id = "impress.notes.properties-toggle";
    summary.textContent = "属性 (" + fields.length + ")";
    details.append(summary);
    const table = document.createElement("div");
    table.className = "im-properties-grid";
    for (const item of fields) {
      const name = document.createElement("span");
      name.className = "im-property-name";
      name.textContent = item.name.slice(0, 160);
      const value = document.createElement("span");
      value.className = "im-property-value";
      value.id = "impress.notes.property-value." + name.textContent;
      value.textContent = item.value.slice(0, 4096);
      table.append(name, value);
    }
    details.append(table);
    details.addEventListener("toggle", () => {
      if (serial === currentEpoch) propertiesExpanded = details.open;
    });
    header.append(details);
  }
  if (diagnostic) {
    const note = document.createElement("p");
    note.className = "im-properties-diagnostic";
    note.textContent = diagnostic + " · 请从更多操作查看 Markdown 源码";
    header.append(note);
  }
  return header;
}
const report = (state, diagramCount, failures, rendered = 0, mathCount = 0) => {
  window.webkit?.messageHandlers?.markdownState?.postMessage({
    state, diagramCount, failures, rendered, mathCount
  });
};


// Safe, local TeX projection. Input is data, never trusted HTML or arbitrary JS.
markdown.inline.ruler.before("escape", "impress_math_inline", (state, silent) => {
  const src=state.src, start=state.pos;
  if(src[start]!=="$" || src[start+1]==="$" || src[start+1]===" ")return false;
  let end=start+1;
  while((end=src.indexOf("$",end))!==-1) {
    if(src[end-1]!=="\\" && src[end-1]!==" " && end>start+1)break;
    end++;
  }
  if(end<0)return false;
  if(!silent) {
    const token=state.push("im_math_inline","math",0);
    token.content=src.slice(start+1,end);
  }
  state.pos=end+1;
  return true;
});
markdown.block.ruler.before("fence","impress_math_display",
  (state,startLine,endLine,silent) => {
    const first=state.src.slice(state.bMarks[startLine]+state.tShift[startLine],
      state.eMarks[startLine]).trim();
    if(first!=="$$")return false;
    let close=startLine+1;
    while(close<endLine) {
      const value=state.src.slice(state.bMarks[close]+state.tShift[close],
        state.eMarks[close]).trim();
      if(value==="$$")break;
      close++;
    }
    if(close===endLine)return false;
    if(!silent) {
      const token=state.push("im_math_display","math",0);
      token.block=true;
      token.content=state.getLines(startLine+1,close,0,true);
      token.map=[startLine,close+1];
    }
    state.line=close+1;
    return true;
  });
function renderMath(source, displayMode) {
  const tex=String(source||"");
  if(tex.length>10000)return "<span class=\"im-diagram-error\">公式过长，请查看源码。</span>";
  try {
    return katex.renderToString(tex,{displayMode,throwOnError:false,
      trust:false,strict:"ignore",maxExpand:200,maxSize:12});
  } catch (_) {
    return "<span class=\"im-diagram-error\">公式语法不可读。</span>";
  }
}
markdown.renderer.rules.im_math_inline=(tokens,idx)=>renderMath(tokens[idx].content,false);
markdown.renderer.rules.im_math_display=(tokens,idx)=>renderMath(tokens[idx].content,true);

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

function promoteCallouts() {
  const kinds = new Set(["NOTE","TIP","IMPORTANT","WARNING","CAUTION","QUOTE","TODO"]);
  for (const block of root.querySelectorAll("blockquote")) {
    const heading = block.querySelector(":scope > p:first-child > strong:first-child");
    if (!heading) continue;
    const kind = (heading.textContent || "").trim().split(/\s*[·:]\s*/)[0].toUpperCase();
    if (!kinds.has(kind)) continue;
    block.classList.add("im-callout","im-callout-" + kind.toLowerCase());
    heading.classList.add("im-callout-heading");
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
// A normal Markdown note does not initialize any diagram engine.
// This fixed, bundled local script is added only for a real graph fence.
let graphicsPromise;
function localGraphics() {
  if (window.ImpressMarkdownGraphics) return Promise.resolve(window.ImpressMarkdownGraphics);
  if (!graphicsPromise) {
    graphicsPromise = new Promise((resolve, reject) => {
      const script = document.createElement("script");
      script.src = "graphs.js";
      script.onload = () => window.ImpressMarkdownGraphics
        ? resolve(window.ImpressMarkdownGraphics) : reject(Error("Missing bundled graph engine"));
      script.onerror = () => reject(Error("Offline graph assets unavailable"));
      document.head.append(script);
    });
  }
  return graphicsPromise;
}
async function drawMermaid(host,source,dark,id) {
  const renderer=await localGraphics();
  await renderer.drawMermaid(host,sanitizeDiagram(source),dark,id);
}
async function drawMarkmap(host,source) {
  const renderer=await localGraphics();
  const instance=await renderer.drawMarkmap(host,cleanText(source));
  liveMaps.push(instance);
}

window.renderImpressMarkdown = async (body, options) => {
  const epoch = ++serial;
  const plain = String(body || "");
  const beforeKey = propertyDocumentKey;
  const beforeScroll = window.scrollY;
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
    firstHeading.hidden = true; // Keep source AST; show one document title.
  }
  root.prepend(renderNativeDocumentHeader(options, epoch));
  markTasks();
  promoteCallouts();
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
    // Preserve the one scroll position when a theme/font/preview projection
    // rerenders the same source. A different document always opens at top.
    requestAnimationFrame(() => {
      if (epoch === serial) {
        window.scrollTo(0, beforeKey === propertyDocumentKey ? beforeScroll : 0);
      }
    });
    const rendered = items.filter((item) => item.querySelector("svg")).length;
    const actualFailures = Math.max(failures, items.length - rendered);
    const mathCount = root.querySelectorAll(".katex").length;
    report(actualFailures ? "partial" : "ready",
      items.length, actualFailures, rendered, mathCount);
  }
};
