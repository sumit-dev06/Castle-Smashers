/* Stone Storm playable ad. Built by tools/build_playable.py from the real game data.
 * Two real campaign levels (6 Moonlit Storehouse, 39 Wrecking Ball), real block sizes, materials,
 * hero abilities and art. Matter.js does the physics. Ends on an install card.
 * Networks: preview | mraid | meta | google (window.SS_NETWORK). */
(function () {
"use strict";
const D = window.SS_DATA, ART = window.SS_ART, SFX = window.SS_SFX, NET = window.SS_NETWORK;
const M = Matter, Body = M.Body, Bodies = M.Bodies, Composite = M.Composite;
const cv = document.getElementById("c"), g = cv.getContext("2d");
const HASH = location.hash.slice(1);
const TEST = HASH.indexOf("test") >= 0;           // #test=1&shots=ang,pow,delay;... (dev only)

// ---------- tuning (playable only; the real numbers come from data/*.json) ----------
const K_DMG = 0.2, ARCHER_HP = 12, MIN_VN = 1.2, STEP = 1000 / 120, GRAV = 1000;
const LEVEL_CFG = [
  { dots: 26, extra: ["bomb", "stone"], hint: "kegs", goal: "Knock out all the archers!" },   // easy: full aim line
  { dots: 7, extra: [], hint: "latch", goal: "Cut the latch, swing the ball!" } // harder: short aim line
];
const ARCHER_W = 34, ARCHER_H = 58;

// ---------- canvas ----------
let W = 0, H = 0, DPR = 1;
function resize() {
  DPR = Math.min(window.devicePixelRatio || 1, 2);
  W = window.innerWidth || 320; H = window.innerHeight || 480;
  cv.width = Math.round(W * DPR); cv.height = Math.round(H * DPR);
}
window.addEventListener("resize", resize);
resize();

// ---------- images ----------
const IMG = {};
function loadImages(done) {
  const keys = Object.keys(ART); let left = keys.length;
  keys.forEach(k => { const im = new Image(); im.onload = im.onerror = () => { if (--left === 0) done(); }; im.src = ART[k]; IMG[k] = im; });
}

// ---------- audio (starts on first touch, muted while the ad is hidden) ----------
let AC = null, muted = false, hidden = false; const BUF = {}, lastPlay = {};
function initAudio() {
  if (AC) return;
  try { AC = new (window.AudioContext || window.webkitAudioContext)(); } catch (e) { return; }
  Object.keys(SFX).forEach(k => {
    const b64 = SFX[k].split(",")[1], bin = atob(b64), u = new Uint8Array(bin.length);
    for (let i = 0; i < bin.length; i++) u[i] = bin.charCodeAt(i);
    AC.decodeAudioData(u.buffer, b => { BUF[k] = b; }, () => {});
  });
}
function sfx(name, vol, rate) {
  if (!AC || muted || hidden || !BUF[name]) return;
  const now = AC.currentTime; if (lastPlay[name] && now - lastPlay[name] < 0.06) return; lastPlay[name] = now;
  const s = AC.createBufferSource(), v = AC.createGain();
  s.buffer = BUF[name]; s.playbackRate.value = rate || (0.94 + Math.random() * 0.12);
  v.gain.value = vol == null ? 0.7 : vol; s.connect(v); v.connect(AC.destination); s.start();
}

// ---------- ad network glue ----------
let installed = false;
function install() {
  sfx("ui_tap", 0.8);
  try {
    if (NET === "meta" && window.FbPlayableAd) { FbPlayableAd.onCTAClick(); return; }
    if (NET === "google" && window.ExitApi) { ExitApi.exit(); return; }
    if (window.mraid && mraid.open) { mraid.open(D.store_url); return; }
  } catch (e) {}
  window.open(D.store_url, "_blank");
}
function whenAdReady(start) {
  let started = false; const go = () => { if (!started) { started = true; start(); } };
  if (NET === "mraid" && window.mraid) {
    const check = () => { if (mraid.isViewable()) go(); };
    mraid.addEventListener("viewableChange", v => { hidden = !v; if (v) go(); if (AC) (v ? AC.resume() : AC.suspend()); });
    if (mraid.getState() === "loading") mraid.addEventListener("ready", check); else check();
    setTimeout(go, 1500); // some SDKs never send viewableChange in their test tools
  } else go();
  document.addEventListener("visibilitychange", () => { hidden = document.hidden; });
}

// ---------- helpers ----------
const clamp = (v, a, b) => v < a ? a : v > b ? b : v;
const lerp = (a, b, t) => a + (b - a) * t;
const rnd = (a, b) => a + Math.random() * (b - a);
function segDist(px, py, ax, ay, bx, by) {
  const dx = bx - ax, dy = by - ay, l2 = dx * dx + dy * dy || 1;
  const t = clamp(((px - ax) * dx + (py - ay) * dy) / l2, 0, 1);
  return Math.hypot(px - ax - t * dx, py - ay - t * dy);
}
function artScale(key) { const m = D.meta[key], im = IMG[key]; return m && im.naturalWidth ? im.naturalWidth / m.w : 1; }

// ---------- game state ----------
let state = "loading", stateT = 0, levelIdx = 0, fails = 0, totalStars = 0, totalScore = 0;
let engine, L, CFG, blocks = [], archers = [], ropes = [], statics = [], frame = null;
let queue = [], hero = null, heroDone = false, turnT = 0, settleT = 0, aiming = null, firedCount = 0;
let score = 0, parts = [], texts = [], whirls = [], pending = [], shake = 0, armAngle = 200, armAnim = null;
let cam = { x: 0, y: 0, z: 1, tx: 0 }, hint = null, hintT = 0, levelT = 0, arrowT = 2, arrows = [];
let resultBtn = null, ctaBtn = null, topCta = null, muteBtn = null, endWin = false, lastPointer = null;
let introPan = 0, shownAbility = {};
const CAT = D.catapult, LAUNCH = D.launch, CS = LAUNCH.visual_scale;

function catPivot() { return { x: CAT.world_pivot[0] * CS, y: CAT.world_pivot[1] * CS }; }
function cupAt(deg) {
  const p = catPivot(), a = deg * Math.PI / 180;
  const lx = (CAT.cup_rim[0] - CAT.arm_pivot[0]) * CS, ly = (CAT.cup_rim[1] - CAT.arm_pivot[1]) * CS;
  return { x: p.x + lx * Math.cos(a) - ly * Math.sin(a), y: p.y + lx * Math.sin(a) + ly * Math.cos(a) };
}
function launchOrigin() { const c = cupAt(CAT.rest_angle_deg); return { x: c.x + 6, y: c.y - 30 }; }

// ---------- level build ----------
function buildLevel(i) {
  levelIdx = i; L = D.levels[i]; CFG = LEVEL_CFG[i];
  engine = M.Engine.create({ positionIterations: 10, velocityIterations: 8, constraintIterations: 6 });
  engine.gravity.y = 1;
  blocks = []; archers = []; ropes = []; statics = []; parts = []; texts = []; whirls = []; pending = []; arrows = [];
  score = 0; firedCount = 0; hero = null; heroDone = false; aiming = null; levelT = 0; arrowT = 2.5; shownAbility = {};
  const addStatic = (x0, x1, top, depth, kind) => {
    const b = Bodies.rectangle((x0 + x1) / 2, top + depth / 2, x1 - x0, depth, { isStatic: true, friction: 1, label: kind });
    b.ss = { kind: "ground" }; statics.push({ x0, x1, top, kind }); Composite.add(engine.world, b);
  };
  addStatic(-2600, L.stage.ledge_right, 0, 1400, "ledge");
  L.stage.bases.forEach(bs => addStatic(bs.x0, bs.x1, bs.top, 1400, "base"));
  L.blocks.forEach((b, idx) => {
    const sh = D.shapes[b.type], mat = D.materials[sh.material], w = sh.size[0], h = sh.size[1];
    const opt = { density: mat.density * 0.001, friction: mat.friction, restitution: mat.bounce, frictionAir: 0.004 };
    let body, yoff = 0;
    if (sh.collider === "circle") body = Bodies.circle(b.x, b.y, w / 2, opt);
    else if (sh.collider === "triangle") {
      yoff = -h / 6;
      body = Bodies.fromVertices(b.x, b.y + h / 6, [[{ x: -w / 2, y: h / 2 }, { x: w / 2, y: h / 2 }, { x: 0, y: -h / 2 }]], opt);
    } else body = Bodies.rectangle(b.x, b.y, w, h, opt);
    body.ss = { kind: "block", type: b.type, matKey: sh.material, mat, hp: mat.hp, max: mat.hp, w, h, yoff, flag: !!b.flag,
      heavy: b.type === "iron_ball", burn: 0, idx };
    if (body.ss.heavy) body.ss.hp = body.ss.max = 99999;
    blocks[idx] = body; Composite.add(engine.world, body);
  });
  L.archers.forEach(a => {
    const body = Bodies.rectangle(a.x, a.y, ARCHER_W, ARCHER_H, { density: 0.0012, friction: 0.9, restitution: 0, chamfer: { radius: 6 } });
    body.ss = { kind: "archer", hp: ARCHER_HP, ko: false, koT: 0, shootT: 0, face: -1 };
    archers.push(body); Composite.add(engine.world, body);
  });
  (L.tethers || []).forEach(t => {
    const target = blocks[t.a], ax = t.attach[0], ay = t.attach[1];
    const c = M.Constraint.create({ pointA: { x: t.x, y: t.y }, bodyB: target, pointB: { x: ax - target.position.x, y: ay - target.position.y },
      length: Math.hypot(ax - t.x, ay - t.y), stiffness: 1, damping: 0.02 });
    c.ss = { cuttable: t.cuttable !== false, cut: false };
    ropes.push(c); Composite.add(engine.world, c);
    if (t.frame) {
      frame = t.frame;
      // the gallows frame is scenery here (no collider) so a direct shot can reach the latch
    }
  });
  if (!(L.tethers || []).some(t => t.frame)) frame = null;
  M.Events.on(engine, "collisionStart", onCollide);
  queue = L.heroes.concat(CFG.extra);
  // camera: whole level fits when the screen is wide enough, else it follows the action
  setupCamera(true);
  introPan = 2.4;
  nextHero();
  setState("intro");
}
function addStaticRect(x, y, w, h) {
  const b = Bodies.rectangle(x, y, w, h, { isStatic: true, friction: 0.9 });
  b.ss = { kind: "frame" }; Composite.add(engine.world, b);
}

// ---------- camera ----------
function worldBounds() { return { l: -470, r: L.camera_right + 60, t: L.camera_top - 40, b: 210 }; }
let follow = false, viewW = 0;
function setupCamera(snap) {
  const B = worldBounds(), fullW = B.r - B.l, fullH = B.b - B.t;
  let z = Math.min(W / fullW, H / fullH);
  follow = false;
  if (W < H * 1.15) { z = Math.min(W / 950, H / fullH); follow = true; }
  cam.z = z; viewW = W / z;
  cam.y = follow ? -0.7 * H / z : B.b - H / z + (H / z - fullH) * 0.15;
  if (!follow) cam.tx = B.l - (W / z - fullW) / 2;
  if (snap) cam.x = follow ? B.l : cam.tx;
}
function camTarget() {
  const B = worldBounds();
  if (!follow) return cam.tx;
  let fx = B.l;
  if (introPan > 0) fx = introPan > 1.0 ? B.r - viewW : B.l;
  else if (hero && !heroDone && hero.ss.launched) fx = hero.position.x - viewW * 0.4;
  else if (state === "play" && settleT > 0) fx = B.r - viewW;
  return clamp(fx, B.l, Math.max(B.l, B.r - viewW));
}
function toScreen(x, y) { return { x: (x - cam.x) * cam.z, y: (y - cam.y) * cam.z }; }
function toWorld(sx, sy) { return { x: sx / cam.z + cam.x, y: sy / cam.z + cam.y }; }

// ---------- turns ----------
function nextHero() {
  hero = null; heroDone = false; settleT = 0;
  if (!queue.length) return false;
  const kind = queue.shift(), H0 = D.heroes[kind], o = launchOrigin();
  hero = { kind, def: H0, position: { x: o.x, y: o.y }, body: null, ss: { launched: false, used: false, hit: false, fuse: -1, age: 0, rest: 0 } };
  return true;
}
function fire(angleDeg, power) {
  const H0 = hero.def, o = launchOrigin(), a = angleDeg * Math.PI / 180, sp = LAUNCH.max_speed * power / 60;
  const b = Bodies.circle(o.x, o.y, H0.radius, { restitution: H0.bounce, friction: H0.friction, frictionAir: 0, density: 0.001 });
  Body.setMass(b, H0.mass * 1.1);
  b.ss = { kind: "hero", hero };
  Composite.add(engine.world, b);
  Body.setVelocity(b, { x: Math.cos(a) * sp, y: Math.sin(a) * sp });
  Body.setAngularVelocity(b, 0.15);
  hero.body = b; hero.ss.launched = true; hero.position = b.position;
  armAnim = { t: 0 }; firedCount++; sfx("launch", 0.9); sfx("whoosh", 0.4);
  if (hint && hint.kind === "drag") hint = null;
  if (!shownAbility[hero.kind]) { shownAbility[hero.kind] = true; showAbilityHint(hero.kind); }
}
const ABILITY_TXT = { bomb: "TAP to BOOM!", fire: "TAP for a FIRE DASH!", stone: "TAP to SLAM down!", cyclone: "TAP for a WHIRLWIND!" };
function showAbilityHint(kind) { hint = { kind: "tap", text: ABILITY_TXT[kind] }; hintT = 0; }

function useAbility() {
  if (!hero || !hero.body || hero.ss.used || heroDone) return;
  const b = hero.body, H0 = hero.def, v = Body.getVelocity(b);
  hero.ss.used = true; sfx("ability", 0.8);
  if (hint && hint.kind === "tap") hint = null;
  if (hero.kind === "bomb") { explode(b.position.x, b.position.y, H0.explosion, true); removeHero(); }
  else if (hero.kind === "stone") {
    Body.setMass(b, b.mass * H0.slam_mass_mult);
    Body.setVelocity(b, { x: v.x * H0.slam_keep_x, y: H0.slam_speed / 60 });
    burst(b.position.x, b.position.y, "#e8eef5", 10, 3);
  } else if (hero.kind === "fire") {
    Body.setVelocity(b, { x: v.x * H0.dash_mult, y: v.y * H0.dash_mult });
    hero.ss.dashed = true; burst(b.position.x, b.position.y, "#ff8a36", 14, 4); sfx("fire", 0.7);
  } else if (hero.kind === "cyclone") {
    whirls.push({ x: b.position.x, y: b.position.y, t: H0.whirl_s, hero: b, def: H0 });
    sfx("whoosh", 0.9, 0.7);
  }
}
function removeHero() {
  if (hero && hero.body) { Composite.remove(engine.world, hero.body); hero.position = { x: hero.body.position.x, y: hero.body.position.y }; hero.body = null; }
  heroDone = true;
}

// ---------- damage ----------
function onCollide(e) {
  for (const p of e.pairs) {
    const a = p.bodyA.parent, b = p.bodyB.parent;
    if (levelT < 1.2 && !(a.ss && a.ss.kind === "hero") && !(b.ss && b.ss.kind === "hero")) continue;
    const va = a.isStatic ? { x: 0, y: 0 } : Body.getVelocity(a), vb = b.isStatic ? { x: 0, y: 0 } : Body.getVelocity(b);
    const n = p.collision.normal, vn = Math.abs((va.x - vb.x) * n.x + (va.y - vb.y) * n.y);
    heroImpact(a, b); heroImpact(b, a);
    if (vn < MIN_VN) continue;
    const ma = a.isStatic ? 0 : a.mass, mb = b.isStatic ? 0 : b.mass;
    const mu = !ma ? mb : !mb ? ma : ma * mb / (ma + mb);
    const E = 0.5 * mu * vn * vn * K_DMG;
    hurt(a, E, b); hurt(b, E, a);
    if (vn > 3) {
      const s = [a, b].find(x => x.ss && x.ss.kind === "block");
      if (s) sfx(s.ss.matKey === "stone" || s.ss.matKey === "tile" || s.ss.matKey === "boulder" ? "stone_hit" : "wood_hit", clamp(vn / 14, 0.15, 0.8));
    }
  }
}
function heroImpact(h, other) {
  if (!h.ss || h.ss.kind !== "hero" || !other.ss) return;
  const hs = h.ss.hero.ss; if (hs.hit) return;
  hs.hit = true;
  const kind = h.ss.hero.kind, H0 = h.ss.hero.def;
  if (kind === "bomb" && hs.fuse < 0) hs.fuse = H0.fuse_after_impact_s;
  if (kind === "fire") pending.push(() => fireBurst(h.position.x, h.position.y, hs.dashed ? H0.burst_radius_dashed : H0.burst_radius, H0.burst_damage));
}
function hurt(body, E, other) {
  const s = body.ss; if (!s || s.dead) return;
  if (s.kind === "block") {
    let m = s.mat.damage_mult;
    if (other.ss && other.ss.kind === "hero") m *= (other.ss.hero.def.material_mult[s.matKey] || 1) * 1.4;
    if (other.ss && other.ss.heavy) m *= 3.2;
    const d = E * m; if (d < 2) return;
    damageBlock(body, d);
  } else if (s.kind === "archer") {
    let d = E; if (other.ss && (other.ss.kind === "hero" || other.ss.heavy)) d *= 3;
    if (d > 1.5) damageArcher(body, d);
  }
}
function damageBlock(b, d) {
  const s = b.ss; if (s.dead) return;
  s.hp -= d;
  if (s.hp <= 0) { s.dead = true; pending.push(() => destroyBlock(b)); }
}
function destroyBlock(b) {
  const s = b.ss; Composite.remove(engine.world, b);
  const x = b.position.x, y = b.position.y;
  const col = { wood: "#c98a4a", crate: "#d9a35e", stone: "#9aa3ad", barrel: "#b0703a", tile: "#d0643c", boulder: "#7a7f86" }[s.matKey] || "#aaa";
  burst(x, y, col, 12, 5, true);
  addScore(s.mat.score, x, y);
  sfx(s.matKey === "stone" || s.matKey === "tile" ? "stone_break" : "wood_break", 0.75);
  if (s.mat.explodes && s.mat.explosion) explode(x, y, s.mat.explosion, false);
}
function damageArcher(a, d) {
  const s = a.ss; if (s.ko) return;
  s.hp -= d; if (s.hp > 0) return;
  koArcher(a);
}
function koArcher(a, fling) {
  const s = a.ss; if (s.ko) return;
  s.ko = true; s.koT = 0;
  a.collisionFilter = { group: 0, category: 0, mask: 0 };
  Body.setInertia(a, a.mass * 400);
  const v = Body.getVelocity(a);
  Body.setVelocity(a, { x: v.x + (fling ? fling.x : rnd(1, 3)), y: Math.min(v.y, 0) - (fling ? fling.y : 7) });
  Body.setAngularVelocity(a, rnd(0.1, 0.25));
  addScore(5000, a.position.x, a.position.y - 40, true);
  sfx("enemy_ko", 0.9); burst(a.position.x, a.position.y, "#ffe9a8", 10, 4);
  shake = Math.max(shake, 4);
}
function addScore(v, x, y, big) { score += v; texts.push({ x, y, t: 0, txt: "+" + v, big: !!big }); }

function explode(x, y, ex, isHero) {
  const R = ex.radius;
  sfx("explosion", 1.0); shake = Math.max(shake, isHero ? 16 : 12);
  for (let i = 0; i < 26; i++) { const a = rnd(0, 6.28), sp = rnd(2, 9); parts.push({ x, y, vx: Math.cos(a) * sp, vy: Math.sin(a) * sp - 1, life: rnd(0.4, 0.8), t: 0, col: i % 3 ? "#ffb33a" : "#ff5a1f", size: rnd(10, 22), type: "fire" }); }
  for (let i = 0; i < 12; i++) parts.push({ x: x + rnd(-40, 40), y: y + rnd(-40, 40), vx: rnd(-1, 1), vy: rnd(-2, -0.5), life: rnd(0.8, 1.5), t: 0, col: "#5a4a48", size: rnd(20, 40), type: "smoke" });
  parts.push({ x, y, vx: 0, vy: 0, life: 0.35, t: 0, col: "#fff2b0", size: R, type: "ring" });
  const all = blocks.concat(archers);
  for (const b of all) {
    if (!b || b.ss.dead || (b.ss.kind === "archer" && b.ss.ko)) continue;
    const dx = b.position.x - x, dy = b.position.y - y, d = Math.hypot(dx, dy);
    if (d > R) continue;
    const f = 1 - d / R, nx = dx / (d || 1), ny = dy / (d || 1) - 0.35;
    const v = Body.getVelocity(b), dv = ex.impulse * 0.03 * f / Math.max(b.mass, 2.5);
    if (b.ss.kind === "archer") { koArcher(b, { x: nx * 6, y: 6 + 4 * f }); continue; }
    Body.setVelocity(b, { x: v.x + nx * dv, y: v.y + ny * dv });
    Body.setAngularVelocity(b, b.angularVelocity + rnd(-0.08, 0.08) * f);
    damageBlock(b, ex.damage * (0.4 + 0.6 * f) * b.ss.mat.damage_mult * (b.ss.heavy ? 0 : 1));
  }
  for (const r of ropes) if (!r.ss.cut && r.ss.cuttable) {
    const p = r.bodyB.position;
    if (segDist(x, y, r.pointA.x, r.pointA.y, p.x + r.pointB.x, p.y + r.pointB.y) < R * 0.6) cutRope(r);
  }
}
function fireBurst(x, y, R, dmg) {
  sfx("fire", 0.9); shake = Math.max(shake, 5);
  for (let i = 0; i < 20; i++) { const a = rnd(0, 6.28), sp = rnd(1, 5); parts.push({ x, y, vx: Math.cos(a) * sp, vy: Math.sin(a) * sp - 1.5, life: rnd(0.4, 0.9), t: 0, col: i % 2 ? "#ffb33a" : "#ff6a1f", size: rnd(8, 18), type: "fire" }); }
  for (const b of blocks) {
    if (!b || b.ss.dead) continue;
    const d = Math.hypot(b.position.x - x, b.position.y - y); if (d > R) continue;
    damageBlock(b, dmg * (D.heroes.fire.material_mult[b.ss.matKey] || 1));
    if (b.ss.mat.flammable) b.ss.burn = Math.max(b.ss.burn, 4.0);
  }
  for (const a of archers) if (!a.ss.ko && Math.hypot(a.position.x - x, a.position.y - y) < R * 0.7) koArcher(a);
}
function cutRope(r) {
  if (r.ss.cut) return; r.ss.cut = true;
  const p = r.bodyB.position;
  Composite.remove(engine.world, r);
  sfx("rope_snap", 1.0); shake = Math.max(shake, 6);
  texts.push({ x: (r.pointA.x + p.x) / 2, y: (r.pointA.y + p.y) / 2 - 30, t: 0, txt: "SNAP!", big: true });
  if (hint && hint.kind === "latch") hint = null;
  Body.setVelocity(r.bodyB, { x: 1.5, y: 0 });
}
function burst(x, y, col, n, sp, chunks) {
  for (let i = 0; i < n; i++) { const a = rnd(0, 6.28), s = rnd(1, sp); parts.push({ x, y, vx: Math.cos(a) * s, vy: Math.sin(a) * s - 2, life: rnd(0.5, 1.1), t: 0, col, size: chunks ? rnd(6, 13) : rnd(4, 8), type: chunks ? "chunk" : "dot", rot: rnd(0, 6) }); }
}

// ---------- simulation ----------
function stepPhysics() {
  M.Engine.update(engine, STEP);
  const dt = STEP / 1000;
  // whirlwinds (Twister)
  for (const w of whirls) {
    w.t -= dt; const H0 = w.def;
    w.x += H0.drift_speed * dt; if (w.hero && hero && hero.body === w.hero) { Body.setPosition(w.hero, { x: w.x, y: w.y - 20 }); Body.setVelocity(w.hero, { x: 0, y: 0 }); }
    for (const b of blocks) {
      if (!b || b.ss.dead || b.ss.heavy) continue;
      const dx = w.x - b.position.x, dy = w.y - b.position.y, d = Math.hypot(dx, dy); if (d > H0.whirl_radius) continue;
      const k = H0.ref_mass * 2 / Math.max(b.mass, H0.ref_mass), v = Body.getVelocity(b);
      Body.setVelocity(b, { x: v.x + (dx / (d || 1) * H0.pull_accel + (dy > 0 ? 1 : -1) * H0.swirl_accel * 0.3) * dt / 60 * k, y: v.y - H0.lift_accel * dt / 60 * k });
    }
    for (const a of archers) if (!a.ss.ko && Math.hypot(w.x - a.position.x, w.y - a.position.y) < H0.whirl_radius * 0.8) koArcher(a, { x: rnd(3, 6), y: 9 });
    if (Math.random() < 0.5) parts.push({ x: w.x + rnd(-60, 60), y: w.y + rnd(-90, 60), vx: rnd(-2, 2), vy: -2, life: 0.6, t: 0, col: "#effffc", size: rnd(6, 12), type: "dot" });
  }
  if (whirls.length && whirls[0].t <= 0) { const w = whirls.shift(); if (hero && hero.body === w.hero) removeHero(); }
  // ropes: the hero cuts what it touches
  if (hero && hero.body) for (const r of ropes) if (!r.ss.cut && r.ss.cuttable) {
    const p = r.bodyB.position;
    if (segDist(hero.body.position.x, hero.body.position.y, r.pointA.x, r.pointA.y, p.x + r.pointB.x, p.y + r.pointB.y) < hero.def.radius + 10) cutRope(r);
  }
  while (pending.length) pending.shift()();
}
function update(dt) {
  levelT += dt; stateT += dt;
  if (introPan > 0) introPan -= dt;
  // fixed physics at 120 Hz
  physAcc += Math.min(dt, 0.05) * 1000;
  while (physAcc >= STEP) { stepPhysics(); physAcc -= STEP; }
  // fire spread
  for (const b of blocks) {
    if (!b || b.ss.dead || b.ss.burn <= 0) continue;
    b.ss.burn -= dt; damageBlock(b, 16 * dt * (b.ss.mat.damage_mult));
    if (Math.random() < dt * 14) parts.push({ x: b.position.x + rnd(-b.ss.w / 3, b.ss.w / 3), y: b.position.y + rnd(-10, 10), vx: rnd(-0.4, 0.4), vy: rnd(-2.5, -1), life: rnd(0.4, 0.8), t: 0, col: Math.random() < 0.5 ? "#ffb33a" : "#ff6a1f", size: rnd(6, 13), type: "fire" });
    if (Math.random() < dt * 1.2) for (const o of blocks) if (o && !o.ss.dead && o.ss.mat.flammable && o.ss.burn <= 0 && Math.hypot(o.position.x - b.position.x, o.position.y - b.position.y) < 90) { o.ss.burn = 3.5; break; }
    for (const a of archers) if (!a.ss.ko && Math.hypot(a.position.x - b.position.x, a.position.y - b.position.y) < 50) damageArcher(a, 10 * dt);
  }
  // kill zone (gaps) and archer state
  const killY = L.gap.surface_y + 70;
  for (const b of blocks) if (b && !b.ss.dead && (b.position.y > killY || b.position.x > L.camera_right + 900)) { b.ss.dead = true; Composite.remove(engine.world, b); splash(b.position.x); }
  for (const a of archers) {
    const s = a.ss;
    if (s.ko) { s.koT += dt; if (s.koT > 1.4 && !s.gone) { s.gone = true; Composite.remove(engine.world, a); } continue; }
    if (a.position.y > killY - 40 || Math.abs(a.angle) > 1.1) koArcher(a);
    s.shootT = Math.max(0, s.shootT - dt);
  }
  // enemy arrows (for show: they fly at your soldiers)
  arrowT -= dt;
  if (arrowT <= 0 && state === "play") {
    arrowT = rnd(1.8, 3.2);
    const alive = archers.filter(a => !a.ss.ko);
    if (alive.length) { const a = alive[(Math.random() * alive.length) | 0]; a.ss.shootT = 0.4;
      const tx = rnd(-330, -200), T = 1.6; arrows.push({ x0: a.position.x - 20, y0: a.position.y - 10, x1: tx, y1: -10, t: 0, T, stuck: 0 }); }
  }
  for (const r of arrows) { if (r.t < r.T) r.t += dt; else r.stuck += dt; }
  arrows = arrows.filter(r => r.stuck < 1.5);
  // hero bookkeeping
  if (hero && hero.body) {
    const b = hero.body; hero.ss.age += dt;
    if (hero.ss.fuse > 0) { hero.ss.fuse -= dt; if (hero.ss.fuse <= 0 && !hero.ss.used) { hero.ss.used = true; explode(b.position.x, b.position.y, hero.def.explosion, true); removeHero(); } }
    if (hero.body) {
      if (b.position.y > killY || b.position.x > L.camera_right + 900 || b.position.x < -1500) { splash(b.position.x); removeHero(); }
      else if (b.speed < 0.25) { hero.ss.rest += dt; if (hero.ss.rest > 1.0) removeHero(); }
      else if (hero.ss.age > 9) removeHero();
    }
  }
  // turn end: wait for things to settle
  if (state === "play" && hero && heroDone) {
    settleT += dt;
    const moving = blocks.some(b => b && !b.ss.dead && b.speed > 0.6) || whirls.length;
    if (alive() === 0) { if (settleT > 0.6) endLevel(true); }
    else if ((settleT > 1.3 && !moving) || settleT > 5) {
      if (!nextHero()) endLevel(false);
    }
  } else if (state === "play" && alive() === 0 && levelT > 1) endLevel(true);
  // arm animation
  if (armAnim) { armAnim.t += dt; const t1 = LAUNCH.arm_swing_s, t2 = LAUNCH.arm_return_s;
    armAngle = armAnim.t < t1 ? lerp(CAT.rest_angle_deg, CAT.fire_angle_deg, armAnim.t / t1) : armAnim.t < t1 + t2 ? lerp(CAT.fire_angle_deg, CAT.rest_angle_deg, (armAnim.t - t1) / t2) : CAT.rest_angle_deg;
    if (armAnim.t > t1 + t2) armAnim = null; }
  else armAngle = aiming ? CAT.rest_angle_deg + CAT.pull_angle_deg * aiming.power * 0.5 : CAT.rest_angle_deg;
  // particles
  for (const p of parts) { p.t += dt; p.x += p.vx * dt * 60; p.y += p.vy * dt * 60; if (p.type === "chunk" || p.type === "dot") p.vy += 0.35 * dt * 60; if (p.type === "fire") p.vy -= 0.05; if (p.rot != null) p.rot += dt * 6; }
  parts = parts.filter(p => p.t < p.life);
  for (const t of texts) t.t += dt; texts = texts.filter(t => t.t < 1.2);
  shake *= Math.pow(0.02, dt);
  // camera
  cam.x = lerp(cam.x, camTarget(), 1 - Math.pow(0.03, dt));
  hintT += dt;
}
let physAcc = 0;
function alive() { return archers.filter(a => !a.ss.ko).length; }
function splash(x) { const c = L.gap.splash || "#e8fdff"; for (let i = 0; i < 10; i++) parts.push({ x: x + rnd(-20, 20), y: L.gap.surface_y, vx: rnd(-2, 2), vy: rnd(-7, -3), life: 0.8, t: 0, col: c, size: rnd(4, 9), type: "dot" }); sfx("splash", 0.5); }

function endLevel(win) {
  if (state !== "play") return;
  const left = queue.length + (hero && !hero.ss.launched ? 1 : 0);
  let stars = 0;
  if (win) { score += left * 10000; stars = left >= 2 ? 3 : left === 1 ? 2 : 1; totalStars += stars; totalScore += score; }
  setState("result"); resultInfo = { win, stars, score, left };
  sfx(win ? "win" : "lose", 0.9);
  if (win) for (let i = 0; i < 40; i++) parts.push({ x: cam.x + rnd(0, W / cam.z), y: cam.y - 20, vx: rnd(-1, 1), vy: rnd(1, 4), life: 2.5, t: 0, col: ["#ffcf3a", "#ff6a8a", "#6fd6ff", "#9cff6a"][i % 4], size: rnd(6, 10), type: "chunk", rot: rnd(0, 6) });
}
let resultInfo = null;
function startPlay() { setState("play"); hint = { kind: "drag", text: levelIdx === 0 ? "DRAG BACK & LET GO TO FLING!" : "HIT THE ROPE TO SWING THE BALL!" }; hintT = 0; }
function setState(s) { state = s; stateT = 0; }

// ---------- input ----------
function pointer(e) { const t = e.changedTouches ? e.changedTouches[0] : e; return { x: t.clientX, y: t.clientY }; }
function hit(btn, p) { return btn && p.x >= btn.x && p.x <= btn.x + btn.w && p.y >= btn.y && p.y <= btn.y + btn.h; }
function onDown(e) {
  e.preventDefault(); initAudio(); if (AC && AC.state === "suspended") AC.resume();
  const p = pointer(e); lastPointer = p;
  if (hit(muteBtn, p)) { muted = !muted; return; }
  if (hit(topCta, p) && state !== "title") { install(); return; }
  if (state === "title") { if (stateT > 0.4) { sfx("ui_tap"); buildLevel(0); } return; }
  if (state === "intro") { introPan = Math.min(introPan, 0.01); startPlay(); return; }
  if (state === "result") { if (hit(resultBtn, p) || stateT > 1.2) resultNext(); return; }
  if (state === "end") { if (hit(ctaBtn, p)) install(); else if (hit(retryBtn, p)) { totalStars = 0; totalScore = 0; fails = 0; buildLevel(0); } return; }
  if (state !== "play" || !hero) return;
  if (hero.ss.launched) { useAbility(); return; }
  aiming = { x0: p.x, y0: p.y, x: p.x, y: p.y, power: 0, angle: -40 };
  sfx("aim_grab", 0.5);
}
function onMove(e) {
  if (!aiming) return; e.preventDefault();
  const p = pointer(e); aiming.x = p.x; aiming.y = p.y; updateAim();
}
function updateAim() {
  const dx = aiming.x0 - aiming.x, dy = aiming.y0 - aiming.y, len = Math.hypot(dx, dy), maxPull = Math.min(W, H) * 0.34;
  aiming.power = clamp(len / maxPull, 0, 1);
  let ang = Math.atan2(dy, dx) * 180 / Math.PI;
  if (dx < 0) ang = dy < 0 ? LAUNCH.min_launch_angle_deg : LAUNCH.max_launch_angle_deg;
  aiming.angle = clamp(ang, LAUNCH.min_launch_angle_deg, LAUNCH.max_launch_angle_deg);
}
function onUp(e) {
  if (!aiming) return; e.preventDefault();
  const a = aiming; aiming = null;
  if (a.power < 0.12) return;
  fire(a.angle, Math.max(a.power, 0.25));
}
function resultNext() {
  if (resultInfo.win) { if (levelIdx === 0) buildLevel(1); else { endWin = true; setState("end"); } }
  else { fails++; if (levelIdx === 0 && fails < 2) buildLevel(0); else if (levelIdx === 0) buildLevel(1); else { endWin = false; setState("end"); } }
}
cv.addEventListener("touchstart", onDown, { passive: false });
cv.addEventListener("touchmove", onMove, { passive: false });
cv.addEventListener("touchend", onUp, { passive: false });
cv.addEventListener("mousedown", e => { if (!e.sourceCapabilities || !e.sourceCapabilities.firesTouchEvents) onDown(e); });
window.addEventListener("mousemove", onMove);
window.addEventListener("mouseup", onUp);
let retryBtn = null;

// ---------- drawing ----------
function drawCover(im, alpha, parallax) {
  if (!im || !im.naturalWidth) return;
  const s = Math.max(W / im.naturalWidth, H / im.naturalHeight) * 1.08;
  const w = im.naturalWidth * s, h = im.naturalHeight * s;
  g.globalAlpha = alpha == null ? 1 : alpha;
  g.drawImage(im, (W - w) / 2 - (parallax || 0), H - h, w, h);
  g.globalAlpha = 1;
}
function drawPiece(key, x0, x1, top) {
  const im = IMG[key], m = D.meta[key]; if (!im || !im.naturalWidth || !m) return;
  const k = im.naturalWidth / m.w, w = (x1 - x0) * 1.06, sx = w / im.naturalWidth;
  const needH = 520, sy = clamp(needH / im.naturalHeight, sx, sx * 1.8);
  const walk = (m.walk_y || m.top_y || 0) * k * sy, cx = (x0 + x1) / 2;
  g.drawImage(im, cx - w / 2, top - walk, w, im.naturalHeight * sy);
  const bottom = top - walk + im.naturalHeight * sy;
}
function drawGap() {
  const G = L.gap, sy = G.surface_y;
  const segs = []; let prev = L.stage.ledge_right;
  L.stage.bases.forEach(b => { segs.push([prev, b.x0]); prev = b.x1; }); segs.push([prev, prev + 3000]);
  for (const [a, b] of segs) {
    const lava = !!G.geyser_color, gr = g.createLinearGradient(0, sy, 0, sy + 400); gr.addColorStop(0, lava ? G.front : G.top); gr.addColorStop(1, G.bottom);
    g.fillStyle = gr; g.fillRect(a - 20, sy, b - a + 40, 760);
    g.strokeStyle = G.wave; g.lineWidth = 4; g.beginPath();
    for (let x = a - 20; x <= b + 20; x += 20) { const y = sy + Math.sin(x * 0.03 + levelT * 2.2) * 3; x === a - 20 ? g.moveTo(x, y) : g.lineTo(x, y); }
    g.stroke();
  }
}
function drawBody(b) {
  const s = b.ss, frac = s.hp / s.max, d = frac > 0.66 ? 0 : frac > 0.33 ? 1 : 2;
  const im = IMG["block_" + s.type + "_" + d];
  g.save(); g.translate(b.position.x, b.position.y); g.rotate(b.angle);
  g.drawImage(im, -s.w / 2, -s.h / 2 + s.yoff, s.w, s.h);
  if (s.burn > 0) { g.globalAlpha = 0.25 + 0.15 * Math.sin(levelT * 20); g.fillStyle = "#ff6a1f"; g.fillRect(-s.w / 2, -s.h / 2 + s.yoff, s.w, s.h); g.globalAlpha = 1; }
  if (s.flag) { const f = IMG.flag; g.drawImage(f, -10, -s.h / 2 + s.yoff - 70, 40, 61); }
  g.restore();
}
function drawUnit(key, x, feetY, h, flip, rot, alpha) {
  const im = IMG[key], m = D.meta[key]; if (!im || !im.naturalWidth) return;
  const k = im.naturalWidth / m.w, s = h / (m.h * k);
  g.save(); g.translate(x, feetY); if (rot) g.rotate(rot); if (flip) g.scale(-1, 1); g.globalAlpha = alpha == null ? 1 : alpha;
  g.drawImage(im, -m.feet_x * k * s, -m.feet_y * k * s, im.naturalWidth * s, im.naturalHeight * s);
  g.restore(); g.globalAlpha = 1;
}
function drawHeroAt(kind, x, y, r, rot, alpha) {
  const key = "hero_" + kind, im = IMG[key], m = D.meta[key]; if (!im || !im.naturalWidth) return;
  const k = im.naturalWidth / m.w, s = r * 1.25 / (m.body_r * k);
  g.save(); g.translate(x, y); if (rot) g.rotate(rot); g.globalAlpha = alpha == null ? 1 : alpha;
  g.drawImage(im, -m.body_c[0] * k * s, -m.body_c[1] * k * s, im.naturalWidth * s, im.naturalHeight * s);
  g.restore(); g.globalAlpha = 1;
}
function drawCatapult() {
  const b = IMG.catapult_base, p = catPivot();
  g.save(); g.translate(0, 0);
  g.drawImage(b, -120 * CS, -CAT.base_ground_y * CS, 240 * CS, 150 * CS);
  g.save(); g.translate(p.x, p.y); g.rotate(armAngle * Math.PI / 180);
  g.drawImage(IMG.catapult_arm, -CAT.arm_pivot[0] * CS, -CAT.arm_pivot[1] * CS, 210 * CS, 60 * CS);
  g.drawImage(IMG.catapult_cup, -CAT.arm_pivot[0] * CS, -CAT.arm_pivot[1] * CS, 210 * CS, 60 * CS);
  g.restore(); g.restore();
}
function drawWorld() {
  const sh = shake > 0.3 ? { x: rnd(-shake, shake), y: rnd(-shake, shake) } : { x: 0, y: 0 };
  g.save(); g.scale(DPR, DPR);
  drawCover(IMG["bg_" + L.realm], 1, (cam.x - worldBounds().l) * cam.z * 0.08);
  g.translate(sh.x, sh.y); g.scale(cam.z, cam.z); g.translate(-cam.x, -cam.y);
  drawGap();
  drawPiece("ledge_" + L.realm, -1700, L.stage.ledge_right, 0);
  L.stage.bases.forEach(bs => drawPiece((bs.x1 - bs.x0 >= 300 || !IMG["base_small_" + L.realm] ? "base_wide_" : "base_small_") + L.realm, bs.x0, bs.x1, bs.top));
  // rope frame
  if (frame) {
    g.fillStyle = "#6b4325"; g.strokeStyle = "#3a2212"; g.lineWidth = 4;
    frame.posts.forEach(px => { g.fillRect(px - 15, frame.top, 30, frame.bottom - frame.top); g.strokeRect(px - 15, frame.top, 30, frame.bottom - frame.top); });
    g.fillRect(frame.beam[0], frame.top - 14, frame.beam[1] - frame.beam[0], 28); g.strokeRect(frame.beam[0], frame.top - 14, frame.beam[1] - frame.beam[0], 28);
  }
  for (const r of ropes) if (!r.ss.cut) {
    const p = r.bodyB.position, latch = r.ss.cuttable;
    g.strokeStyle = latch ? "#e8c27a" : "#5b3b1f"; g.lineWidth = latch ? 6 : 7; g.beginPath(); g.moveTo(r.pointA.x, r.pointA.y); g.lineTo(p.x + r.pointB.x, p.y + r.pointB.y); g.stroke();
    g.fillStyle = "#3a2212"; g.beginPath(); g.arc(r.pointA.x, r.pointA.y, 7, 0, 7); g.fill();
  }
  // soldiers + wizard
  const win = state === "result" && resultInfo && resultInfo.win;
  drawUnit(win ? "soldier_cheer" : "soldier_idle", -265, 2, 74, false, 0);
  drawUnit(win ? "soldier_cheer" : "soldier_idle", -335, 2, 74, false, 0);
  g.drawImage(IMG.wizard_idle, -205 - 50, -112 + Math.sin(levelT * 2) * 1.5, 100, 114);
  drawCatapult();
  // waiting heroes behind the catapult
  if (false) queue.forEach((k, i) => drawHeroAt(k, LAUNCH.hero_wait_x[Math.min(i, 5)] - 300 + i * 6 + 70, -30 + Math.abs(Math.sin(levelT * 3 + i)) * -4, 26, 0));
  for (const b of blocks) if (b && !b.ss.dead) drawBody(b);
  for (const a of archers) {
    if (a.ss.gone) continue;
    const s = a.ss, key = s.ko ? "archer_ko" : s.shootT > 0 ? "archer_shoot" : "archer_idle";
    drawUnit(key, a.position.x, a.position.y + ARCHER_H / 2 + 2, 78, false, a.angle, s.ko ? clamp(1.4 - s.koT, 0, 1) : 1);
  }
  // arrows
  for (const r of arrows) {
    const t = Math.min(r.t / r.T, 1), x = lerp(r.x0, r.x1, t), y = lerp(r.y0, r.y1, t) - Math.sin(t * Math.PI) * 260;
    const t2 = Math.min(t + 0.02, 1), x2 = lerp(r.x0, r.x1, t2), y2 = lerp(r.y0, r.y1, t2) - Math.sin(t2 * Math.PI) * 260;
    g.save(); g.translate(x, y); g.rotate(Math.atan2(y2 - y, x2 - x) + Math.PI); g.globalAlpha = r.stuck ? clamp(1.5 - r.stuck, 0, 1) : 1;
    g.drawImage(IMG.arrow, -30, -6, 60, 12); g.restore(); g.globalAlpha = 1;
  }
  // hero
  if (hero) {
    if (hero.body) drawHeroAt(hero.kind, hero.body.position.x, hero.body.position.y, hero.def.radius, hero.body.angle);
    else if (!hero.ss.launched) { const c = cupAt(armAngle); drawHeroAt(hero.kind, c.x + 6, c.y - 26, hero.def.radius, 0); }
  }
  for (const w of whirls) { // funnel
    g.strokeStyle = "rgba(239,255,252,0.7)"; g.lineWidth = 6;
    for (let i = 0; i < 9; i++) { const f = i / 8, rr = lerp(30, 160, f) * (0.8 + 0.2 * Math.sin(levelT * 9 + i)); g.beginPath(); g.ellipse(w.x + Math.sin(levelT * 7 + i) * 10, w.y + 120 - f * 260, rr, rr * 0.28, 0, 0, 7); g.stroke(); }
  }
  // aim dots
  if (aiming && aiming.power >= 0.12) {
    const o = launchOrigin(), a = aiming.angle * Math.PI / 180, sp = LAUNCH.max_speed * Math.max(aiming.power, 0.25);
    const vx = Math.cos(a) * sp, vy = Math.sin(a) * sp;
    for (let i = 1; i <= CFG.dots; i++) { const t = i * LAUNCH.dot_step_s, x = o.x + vx * t, y = o.y + vy * t + 0.5 * GRAV * t * t;
      g.fillStyle = "rgba(255,255,255," + (1 - i / (CFG.dots + 4)) + ")"; g.beginPath(); g.arc(x, y, 7 - i * 0.12, 0, 7); g.fill(); }
  }
  // particles
  for (const p of parts) {
    const f = 1 - p.t / p.life;
    if (p.type === "ring") { g.strokeStyle = "rgba(255,242,176," + f + ")"; g.lineWidth = 14 * f; g.beginPath(); g.arc(p.x, p.y, p.size * (1 - f * 0.7), 0, 7); g.stroke(); continue; }
    g.globalAlpha = p.type === "smoke" ? f * 0.5 : f; g.fillStyle = p.col;
    if (p.type === "chunk") { g.save(); g.translate(p.x, p.y); g.rotate(p.rot); g.fillRect(-p.size / 2, -p.size / 2, p.size, p.size * 0.8); g.strokeStyle = "#3a2212"; g.lineWidth = 2; g.strokeRect(-p.size / 2, -p.size / 2, p.size, p.size * 0.8); g.restore(); }
    else { g.beginPath(); g.arc(p.x, p.y, p.size * (p.type === "smoke" ? 2 - f : f + 0.3), 0, 7); g.fill(); }
  }
  g.globalAlpha = 1;
  // hint markers in world
  if (state === "play" || state === "intro") drawWorldHints();
  // floating score
  for (const t of texts) { const f = t.t / 1.2; label(t.txt, t.x, t.y - f * 60, t.big ? 40 : 26, t.big ? "#ffcf3a" : "#ffffff", 1 - f * f, "center"); }
  // corner foreground (realm art)
  const fg = IMG["fg_" + L.realm]; if (fg && fg.naturalWidth) { const B = worldBounds(), fh = (B.b - B.t) * 0.3, fw = fh * fg.naturalWidth / fg.naturalHeight; g.drawImage(fg, B.r + 140 - fw, 60 - fh, fw, fh); }
  g.restore();
}
function drawWorldHints() {
  const pulse = 1 + 0.12 * Math.sin(levelT * 6);
  if (CFG.hint === "kegs" && firedCount === 0) {
    for (const b of blocks) if (b && !b.ss.dead && b.ss.matKey === "barrel") ring(b.position.x, b.position.y, 46 * pulse, "#ffcf3a");
    const k = blocks.find(b => b && b.ss.matKey === "barrel"); if (k) label("HIT THE KEGS!", k.position.x, k.position.y - 80 - 6 * Math.sin(levelT * 4), 40, "#ffcf3a", 1, "center");
  }
  if (CFG.hint === "latch") {
    const r = ropes.find(r => r.ss.cuttable && !r.ss.cut);
    if (r) { const c = L.callouts[0].target.split(",").map(Number); ring(c[0], c[1], 40 * pulse, "#ffcf3a"); label(L.callouts[0].label, c[0], c[1] - 70 - 6 * Math.sin(levelT * 4), 42, "#ffcf3a", 1, "center"); }
  }
}
function ring(x, y, r, col) { g.strokeStyle = col; g.lineWidth = 5; g.setLineDash([12, 8]); g.lineDashOffset = -levelT * 30; g.beginPath(); g.arc(x, y, r, 0, 7); g.stroke(); g.setLineDash([]); }
function label(txt, x, y, size, col, alpha, align, font) {
  g.globalAlpha = alpha == null ? 1 : alpha; g.font = size + "px " + (font || "Lilita") + ", Arial Black, sans-serif"; g.textAlign = align || "left"; g.textBaseline = "middle";
  g.lineJoin = "round"; g.lineWidth = Math.max(3, size * 0.2); g.strokeStyle = "#3a2212"; g.strokeText(txt, x, y); g.fillStyle = col; g.fillText(txt, x, y); g.globalAlpha = 1;
}
function pill(x, y, w, h, col, txt, size, glow) {
  g.save();
  if (glow) { g.shadowColor = col; g.shadowBlur = glow; }
  g.fillStyle = "#3a2212"; rr(x - 3, y - 3 + 4, w + 6, h + 6, (h + 6) / 2); g.fill();
  const gr = g.createLinearGradient(0, y, 0, y + h); gr.addColorStop(0, col[0]); gr.addColorStop(1, col[1]); g.fillStyle = gr; rr(x, y, w, h, h / 2); g.fill();
  g.restore();
  g.fillStyle = "rgba(255,255,255,0.35)"; rr(x + h * 0.3, y + 4, w - h * 0.6, h * 0.3, h * 0.15); g.fill();
  label(txt, x + w / 2, y + h / 2 + 1, size, "#ffffff", 1, "center");
  return { x, y, w, h };
}
function rr(x, y, w, h, r) { g.beginPath(); g.moveTo(x + r, y); g.arcTo(x + w, y, x + w, y + h, r); g.arcTo(x + w, y + h, x, y + h, r); g.arcTo(x, y + h, x, y, r); g.arcTo(x, y, x + w, y, r); g.closePath(); }
function panel(x, y, w, h) { g.fillStyle = "rgba(58,34,18,0.92)"; rr(x - 4, y - 4, w + 8, h + 8, 26); g.fill(); const gr = g.createLinearGradient(0, y, 0, y + h); gr.addColorStop(0, "#fff3d6"); gr.addColorStop(1, "#f2d9a6"); g.fillStyle = gr; rr(x, y, w, h, 22); g.fill(); }
function logo(cx, cy, size) {
  const bob = Math.sin(stateT * 2) * size * 0.04;
  label("STONE", cx, cy - size * 0.52 + bob, size, "#ffcf3a", 1, "center");
  label("STORM", cx, cy + size * 0.45 + bob, size * 1.12, "#ffcf3a", 1, "center");
}
function drawHand(x, y, press) {
  g.save(); g.translate(x, y); const s = press ? 0.9 : 1; g.scale(s, s);
  g.fillStyle = "rgba(255,255,255,0.25)"; g.beginPath(); g.arc(0, 0, 34, 0, 7); g.fill();
  g.fillStyle = "#fff"; g.strokeStyle = "#3a2212"; g.lineWidth = 4;
  rr(-12, -6, 24, 44, 11); g.fill(); g.stroke(); rr(-7, -38, 14, 40, 7); g.fill(); g.stroke();
  g.restore();
}
function drawUI() {
  g.save(); g.scale(DPR, DPR);
  const u = Math.min(W, H) / 380;
  // top bar
  if (state === "play" || state === "intro" || state === "result") {
    label(W < H ? "LEVEL " + L.id : "LEVEL " + L.id + "  " + L.name.toUpperCase(), 14 * u, 22 * u, 17 * u, "#ffffff", 1, "left");
    const n = alive(); drawUnit("archer_idle", 22 * u, 66 * u, 34 * u, false, 0);
    label("x " + n, 42 * u, 52 * u, 20 * u, n ? "#ffcf3a" : "#9cff6a", 1, "left");
    label(String(score), W < H ? 120 * u : W / 2, W < H ? 52 * u : 22 * u, 20 * u, "#ffffff", 1, "center");
    // hero queue
    const all = (hero && !hero.ss.launched ? [hero.kind] : []).concat(queue);
    all.forEach((k, i) => { g.save(); g.scale(1, 1); g.restore(); const x = 24 * u + i * 34 * u, y = H - 26 * u;
      g.fillStyle = "rgba(58,34,18,0.55)"; g.beginPath(); g.arc(x, y, 16 * u, 0, 7); g.fill();
      g.save(); g.translate(x, y); g.scale(u, u); g.translate(-x, -y); drawHeroAt(k, x, y, 12.5, 0, 1); g.restore(); });
  }
  // mute + always-on install
  muteBtn = { x: W - 44 * u, y: 8 * u, w: 36 * u, h: 36 * u };
  g.fillStyle = "rgba(58,34,18,0.6)"; rr(muteBtn.x, muteBtn.y, muteBtn.w, muteBtn.h, 10 * u); g.fill();
  g.fillStyle = "#fff"; g.beginPath(); const mx = muteBtn.x + 9 * u, my = muteBtn.y + 18 * u;
  g.moveTo(mx, my - 5 * u); g.lineTo(mx + 6 * u, my - 5 * u); g.lineTo(mx + 13 * u, my - 11 * u); g.lineTo(mx + 13 * u, my + 11 * u); g.lineTo(mx + 6 * u, my + 5 * u); g.lineTo(mx, my + 5 * u); g.fill();
  if (muted) { g.strokeStyle = "#ff5a4a"; g.lineWidth = 3 * u; g.beginPath(); g.moveTo(mx - 2 * u, my - 12 * u); g.lineTo(mx + 20 * u, my + 12 * u); g.stroke(); }
  if (state !== "title" && state !== "end") topCta = pill(W - 150 * u, 10 * u, 98 * u, 32 * u, ["#7ee35a", "#2f9e2a"], "INSTALL", 15 * u); else topCta = null;
  // hints
  if (state === "play" && hint) {
    const a = 0.85 + 0.15 * Math.sin(hintT * 6);
    if (hint.kind === "drag" && !aiming) {
      const c = toScreen(launchOrigin().x, launchOrigin().y), cyc = (hintT % 2.2) / 2.2, t = clamp((cyc - 0.15) / 0.55, 0, 1), ease = t * t * (3 - 2 * t);
      const hx = c.x + 30 * u - ease * 90 * u, hy = c.y + 40 * u + ease * 60 * u;
      if (cyc > 0.15 && cyc < 0.8) { g.strokeStyle = "rgba(255,255,255,0.8)"; g.setLineDash([6 * u, 6 * u]); g.lineWidth = 3 * u; g.beginPath(); g.moveTo(c.x + 30 * u, c.y + 40 * u); g.lineTo(hx, hy); g.stroke(); g.setLineDash([]); }
      drawHand(hx, hy, cyc > 0.15 && cyc < 0.8);
      banner(hint.text, a, u);
    } else if (hint.kind !== "drag") banner(hint.text, a, u);
  }
  if (state === "intro") {
    const a = clamp(stateT * 3, 0, 1);
    g.globalAlpha = a; panel(W / 2 - 150 * u, H * 0.3 - 46 * u, 300 * u, 92 * u); g.globalAlpha = 1;
    label("LEVEL " + (levelIdx + 1) + " OF 2", W / 2, H * 0.3 - 22 * u, 16 * u, "#ff9a3a", a, "center");
    label(L.name.toUpperCase(), W / 2, H * 0.3 + 2 * u, 25 * u, "#ffcf3a", a, "center");
    label(CFG.goal, W / 2, H * 0.3 + 28 * u, 14 * u, "#ffffff", a, "center", "Fredoka");
    if (stateT > 2.4) startPlay();
  }
  if (state === "result") drawResult(u);
  if (state === "title") drawTitle(u);
  if (state === "end") drawEnd(u);
  g.restore();
}
function banner(txt, a, u) {
  const w = Math.min(W - 20 * u, 330 * u), y = H * (H > W ? 0.2 : 0.17);
  g.globalAlpha = 0.9 * a; g.fillStyle = "rgba(58,34,18,0.85)"; rr(W / 2 - w / 2, y - 20 * u, w, 40 * u, 20 * u); g.fill(); g.globalAlpha = 1;
  label(txt, W / 2, y + 1, 19 * u, "#ffcf3a", 1, "center");
}
function drawResult(u) {
  const R = resultInfo, a = clamp(stateT * 3, 0, 1);
  g.fillStyle = "rgba(20,10,30," + 0.45 * a + ")"; g.fillRect(0, 0, W, H);
  const pw = 300 * u, ph = 210 * u, px = W / 2 - pw / 2, py = H / 2 - ph / 2 - (1 - a) * 40;
  panel(px, py, pw, ph);
  label(R.win ? (levelIdx === 0 ? "STOREHOUSE SMASHED!" : "WRECKED IT!") : "SO CLOSE!", W / 2, py + 34 * u, 24 * u, R.win ? "#ffcf3a" : "#ff8a5a", 1, "center");
  for (let i = 0; i < 3; i++) { const on = i < R.stars && stateT > 0.35 + i * 0.25, s = (on ? 1 + 0.2 * Math.max(0, 1 - (stateT - 0.35 - i * 0.25) * 4) : 0.85) * 26 * u;
    star(W / 2 + (i - 1) * 62 * u, py + 88 * u - (i === 1 ? 10 * u : 0), s, on); if (on && !R["s" + i]) { R["s" + i] = 1; sfx("star", 0.8, 1 + i * 0.12); } }
  label(R.win ? "SCORE " + R.score : "Out of heroes. One more try!", W / 2, py + 132 * u, 17 * u, "#ffffff", 1, "center", "Fredoka");
  const label2 = R.win ? (levelIdx === 0 ? "NEXT LEVEL" : "CONTINUE") : (levelIdx === 0 && fails < 1 ? "TRY AGAIN" : "CONTINUE");
  resultBtn = pill(W / 2 - 90 * u, py + 158 * u, 180 * u, 38 * u, ["#ffd34a", "#e8901a"], label2, 18 * u);
}
function star(x, y, r, on) {
  g.save(); g.translate(x, y); g.beginPath();
  for (let i = 0; i < 10; i++) { const rad = i % 2 ? r * 0.48 : r, a = -Math.PI / 2 + i * Math.PI / 5; g.lineTo(Math.cos(a) * rad, Math.sin(a) * rad); }
  g.closePath(); g.lineWidth = 5; g.strokeStyle = "#3a2212"; g.stroke(); g.fillStyle = on ? "#ffcf3a" : "#c9b48a"; g.fill(); g.restore();
}
function drawTitle(u) {
  drawCover(IMG.bg_1, 1, 0);
  g.fillStyle = "rgba(20,10,40,0.35)"; g.fillRect(0, 0, W, H);
  const port = H > W, cx = W / 2, cy = port ? H * 0.26 : H * 0.3;
  logo(cx, cy, (port ? 56 : 62) * u);
  label("Fling heroes. Smash castles.", cx, cy + 86 * u, 17 * u, "#ffffff", 1, "center", "Fredoka");
  const kinds = ["stone", "bomb", "fire", "cyclone"];
  kinds.forEach((k, i) => { const x = cx + (i - 1.5) * 66 * u, y = (port ? H * 0.56 : H * 0.66) - Math.abs(Math.sin(stateT * 3 + i * 0.8)) * 14 * u;
    g.save(); g.translate(x, y); g.scale(u, u); drawHeroAt(k, 0, 0, 24, Math.sin(stateT * 2 + i) * 0.15); g.restore(); });
  const s = 1 + 0.05 * Math.sin(stateT * 5);
  g.save(); g.translate(cx, port ? H * 0.74 : H * 0.88); g.scale(s, s);
  pill(-100 * u, -22 * u, 200 * u, 44 * u, ["#7ee35a", "#2f9e2a"], "TAP TO PLAY", 21 * u); g.restore();
}
function drawEnd(u) {
  drawCover(IMG.bg_4, 1, 0);
  g.fillStyle = "rgba(20,10,40,0.45)"; g.fillRect(0, 0, W, H);
  const port = H > W, cx = W / 2;
  logo(cx, port ? H * 0.17 : H * 0.2, (port ? 50 : 52) * u);
  label(endWin ? "YOU'RE A NATURAL!" : "SO CLOSE!", cx, port ? H * 0.31 : H * 0.4, 22 * u, endWin ? "#9cff6a" : "#ff9a5a", 1, "center");
  for (let i = 0; i < 6; i++) star(cx + (i - 2.5) * 30 * u, port ? H * 0.37 : H * 0.48, 12 * u, i < totalStars);
  const lines = ["120 levels across 8 realms", "Bosses, traps, ropes & gadgets", "Free to play"];
  lines.forEach((t, i) => label("• " + t, cx, (port ? H * 0.44 : H * 0.57) + i * 24 * u, 16 * u, "#ffffff", 1, "center", "Fredoka"));
  const kinds = ["stone", "bomb", "fire", "cyclone"];
  kinds.forEach((k, i) => { const x = cx + (i - 1.5) * 60 * u, y = (port ? H * 0.64 : H * 0.15) + (port ? 0 : 0) - Math.abs(Math.sin(stateT * 3 + i * 0.8)) * 12 * u;
    if (!port) return; g.save(); g.translate(x, y); g.scale(u, u); drawHeroAt(k, 0, 0, 22, 0); g.restore(); });
  const s = 1 + 0.06 * Math.sin(stateT * 5);
  g.save(); g.translate(cx, port ? H * 0.78 : H * 0.8); g.scale(s, s);
  pill(-120 * u, -27 * u, 240 * u, 54 * u, ["#7ee35a", "#2f9e2a"], "PLAY FREE", 26 * u, 24 * u); g.restore();
  ctaBtn = { x: cx - 130 * u, y: (port ? H * 0.78 : H * 0.8) - 30 * u, w: 260 * u, h: 60 * u };
  label("Play again", cx, (port ? H * 0.78 : H * 0.8) + 50 * u, 14 * u, "#ffffff", 0.8, "center", "Fredoka");
  retryBtn = { x: cx - 60 * u, y: (port ? H * 0.78 : H * 0.8) + 38 * u, w: 120 * u, h: 26 * u };
}

// ---------- main loop ----------
let last = 0;
function frameLoop(ts) {
  const dt = last ? Math.min((ts - last) / 1000, 0.05) : 0.016; last = ts;
  if (!hidden) {
    if (state === "play" || state === "intro" || state === "result") { update(dt); }
    else stateT += dt;
    g.setTransform(1, 0, 0, 1, 0, 0); g.clearRect(0, 0, cv.width, cv.height);
    if (L && state !== "title" && state !== "end") drawWorld();
    drawUI();
    if (TEST) testTick();
  }
  requestAnimationFrame(frameLoop);
}
let lastW = 0, lastH = 0;
setInterval(() => { if ((W !== lastW || H !== lastH) && L) { setupCamera(false); } lastW = W; lastH = H; }, 200);

// ---------- dev test hook: #test&lvl=1&shots=ang,pow,abilityDelay;... ----------
const TP = {}; HASH.split("&").forEach(kv => { const [k, v] = kv.split("="); TP[k] = v; });
let testShots = (TP.shots || "").split(";").filter(Boolean).map(s => s.split(",").map(Number)), testWait = 0, testFired = 0;
function testTick() {
  if (state === "play" && hero && !hero.ss.launched && testShots.length) { testWait += 1 / 60; if (testWait > 0.3) { testWait = 0; const s = testShots.shift(); fire(s[0], s[1]); testFired = performance.now(); if (s[2] >= 0) setTimeout(useAbility, s[2] * 1000); } }
  document.title = JSON.stringify({ state, level: levelIdx, alive: L ? alive() : -1, score, left: queue.length, win: resultInfo ? resultInfo.win : null, cut: ropes.filter(r => r.ss.cut).length, t: Math.round(levelT) });
}

loadImages(() => whenAdReady(() => {
  if (TEST) { buildLevel(+(TP.lvl || 0)); if (TP.state === "end") { endWin = true; totalStars = 5; setState("end"); } else if (TP.state === "title") setState("title"); else { introPan = 0; setState("play"); } }
  else setState("title");
  requestAnimationFrame(frameLoop);
}));
})();
