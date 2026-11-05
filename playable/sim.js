// Headless test driver for the playable: runs the built HTML in Node with a stub canvas.
// node playable/sim.js <lvl> "<ang,pow,delay;...>" [seconds]  -> prints final state JSON
const fs = require("fs"), vm = require("vm"), path = require("path");
const html = fs.readFileSync(path.join(__dirname, "../build/playable/stone_storm_preview.html"), "utf8");
const scripts = [...html.matchAll(/<script>([\s\S]*?)<\/script>/g)].map(m => m[1]);
const lvl = process.argv[2] || "0", shots = process.argv[3] || "", secs = +(process.argv[4] || 40);
const noop = () => {}, grad = { addColorStop: noop };
const ctx = new Proxy({}, { get: (t, k) => k === "createLinearGradient" ? () => grad : k === "measureText" ? () => ({ width: 10 }) : (k in t ? t[k] : noop), set: (t, k, v) => { t[k] = v; return true; } });
let raf = null;
const doc = { title: "", hidden: false, getElementById: () => ({ getContext: () => ctx, addEventListener: noop, width: 0, height: 0 }), addEventListener: noop };
class Img { constructor() { this.naturalWidth = 100; this.naturalHeight = 100; } set src(v) { this._s = v; timers.push({ f: () => this.onload && this.onload(), at: 0 }); } }
const win = { innerWidth: 844, innerHeight: 390, devicePixelRatio: 1, addEventListener: noop, requestAnimationFrame: f => { raf = f; },
  location: { hash: "#test&lvl=" + lvl + "&shots=" + shots }, document: doc, Image: Img, performance: { now: () => T }, open: noop };
let T = 0;
const timers = [];
win.setTimeout = (f, ms) => timers.push({ f, at: T + (ms || 0) });
win.setInterval = noop; win.atob = s => Buffer.from(s, "base64").toString("binary");
win.window = win; win.self = win; win.console = console;
const sb = vm.createContext(Object.assign(win, { Matter: undefined }));
scripts.forEach(s => vm.runInContext(s, sb));
const flush = () => { for (let i = timers.length - 1; i >= 0; i--) if (timers[i].at <= T) { const t = timers.splice(i, 1)[0]; t.f(); } };
for (let i = 0; i < 5; i++) flush();
for (let f = 0; f < secs * 60 && raf; f++) { T += 1000 / 60; flush(); const r = raf; raf = null; r(T); }
console.log(doc.title);
