import { build } from "esbuild";
import { cpSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { createHash } from "node:crypto";
import { resolve } from "node:path";

const root = resolve(import.meta.dirname, "..", "..");
const destination = resolve(root, "aReuImpress-iPhone", "Resources", "DiagramReader");
mkdirSync(destination, { recursive: true });
await build({
  entryPoints: [resolve(import.meta.dirname, "host.js")],
  outfile: resolve(destination, "reader.js"),
  bundle: true, platform: "browser", format: "iife", target: ["safari17"],
  minify: true, legalComments: "linked", define: { "process.env.NODE_ENV": '"production"' },
  logLevel: "warning"
});
cpSync(resolve(import.meta.dirname, "index.html"), resolve(destination, "index.html"));
cpSync(resolve(import.meta.dirname, "THIRD_PARTY_LICENSES.txt"),
  resolve(destination, "THIRD_PARTY_LICENSES.txt"));
const manifest = {};
for (const file of ["reader.js", "index.html", "THIRD_PARTY_LICENSES.txt"]) {
  const data = readFileSync(resolve(destination, file));
  manifest[file] = { size: data.byteLength,
    sha256: createHash("sha256").update(data).digest("hex") };
}
manifest.engines = { mermaid: "11.12.2", "markmap-lib": "0.18.12", "markmap-view": "0.18.12" };
manifest.licenses = { mermaid: "MIT", markmap: "MIT", esbuild: "MIT" };
writeFileSync(resolve(destination, "manifest.json"), JSON.stringify(manifest, null, 2) + "\n");
console.log("OFFLINE_DIAGRAM_ASSETS", JSON.stringify(manifest));