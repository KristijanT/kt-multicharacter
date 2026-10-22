const $ = (s) => document.querySelector(s);
const post = (n, d = {}) =>
  fetch(`https://${GetParentResourceName()}/${n}`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(d),
  })
    .then((r) => r.json())
    .catch(() => null);
const esc = (s) =>
  String(s ?? "").replace(
    /[&<>"']/g,
    (c) =>
      ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[
        c
      ],
  );

/* ---------- ikone ---------- */
const P = {
  user: '<path d="M19 21v-2a4 4 0 0 0-4-4H9a4 4 0 0 0-4 4v2"/><circle cx="12" cy="7" r="4"/>',
  lock: '<rect width="18" height="11" x="3" y="11" rx="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/>',
  plus: '<path d="M5 12h14M12 5v14"/>',
  play: '<polygon points="6 3 20 12 6 21 6 3" fill="currentColor"/>',
  pause:
    '<rect x="14" y="4" width="4" height="16" rx="1" fill="currentColor"/><rect x="6" y="4" width="4" height="16" rx="1" fill="currentColor"/>',
  next: '<polygon points="5 4 15 12 5 20 5 4" fill="currentColor"/><line x1="19" x2="19" y1="5" y2="19"/>',
  prev: '<polygon points="19 20 9 12 19 4 19 20" fill="currentColor"/><line x1="5" x2="5" y1="19" y2="5"/>',
  trash:
    '<path d="M3 6h18M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"/>',
  vol: '<polygon points="11 5 6 9 2 9 2 15 6 15 11 19 11 5"/><path d="M15.5 8.5a5 5 0 0 1 0 7"/>',
  music:
    '<path d="M9 18V5l12-2v13"/><circle cx="6" cy="18" r="3"/><circle cx="18" cy="16" r="3"/>',
  pin: '<path d="M20 10c0 6-8 12-8 12s-8-6-8-12a8 8 0 0 1 16 0Z"/><circle cx="12" cy="10" r="3"/>',
  back: '<path d="m15 18-6-6 6-6"/>',
};
const ic = (n) =>
  `<svg class="ic" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">${P[n] || ""}</svg>`;

/* ---------- zvuk (bez fajlova) ---------- */
let actx;
function tick(freq = 520, dur = 0.06) {
  try {
    actx = actx || new (window.AudioContext || window.webkitAudioContext)();
    const o = actx.createOscillator(),
      g = actx.createGain();
    o.type = "sine";
    o.frequency.value = freq;
    g.gain.value = 0.04;
    g.gain.exponentialRampToValueAtTime(0.0001, actx.currentTime + dur);
    o.connect(g);
    g.connect(actx.destination);
    o.start();
    o.stop(actx.currentTime + dur);
  } catch (e) {}
}

/* ---------- state ---------- */
let S = {
  chars: [],
  cfg: {},
  sel: null,
  cart: {},
  world: null,
  track: 0,
  effect: "none",
};
const t = (k) => (S.cfg.lang && S.cfg.lang[k]) || k;
const money = (n) => (S.cfg.currency || "$") + Number(n || 0).toLocaleString();
const initials = (c) =>
  ((c.firstname || "?")[0] + (c.lastname || "")[0]).toUpperCase();

function toast(key) {
  const el = $("#toast");
  el.textContent = t(key);
  el.classList.remove("hidden");
  clearTimeout(toast.h);
  toast.h = setTimeout(() => el.classList.add("hidden"), 3000);
}

/* ---------- muzika ---------- */
const audio = new Audio();
audio.loop = false;
function saveSettings() {
  post("saveSettings", {
    volume: audio.volume,
    track: S.track + 1,
    effect: S.effect,
  });
}
function loadTrack(i, play = true) {
  const tr = S.cfg.music.tracks;
  if (!tr.length) return;
  S.track = (i + tr.length) % tr.length;
  audio.src = tr[S.track].file;
  if (play) audio.play().catch(() => {});
  renderPlayer();
  saveSettings();
}
audio.addEventListener("ended", () => loadTrack(S.track + 1));
audio.addEventListener("play", renderPlayer);
audio.addEventListener("pause", renderPlayer);

function renderPlayer() {
  const el = $("#player"),
    m = S.cfg.music;
  if (!m || !m.enabled || !m.tracks.length) {
    el.classList.add("hidden");
    return;
  }
  el.classList.remove("hidden");
  const tr = m.tracks[S.track];
  el.innerHTML = `
    <div class="cover">${ic("music")}</div>
    <div class="meta"><b>${esc(tr.label)}</b><small>${S.track + 1} / ${m.tracks.length}</small></div>
    <button id="p-prev">${ic("prev")}</button>
    <button class="big" id="p-play">${ic(audio.paused ? "play" : "pause")}</button>
    <button id="p-next">${ic("next")}</button>
    ${ic("vol")}<input id="p-vol" type="range" min="0" max="100" value="${Math.round(audio.volume * 100)}">`;
  $("#p-prev").onclick = () => {
    tick();
    loadTrack(S.track - 1);
  };
  $("#p-next").onclick = () => {
    tick();
    loadTrack(S.track + 1);
  };
  $("#p-play").onclick = () => {
    tick();
    audio.paused ? audio.play().catch(() => {}) : audio.pause();
  };
  $("#p-vol").oninput = (e) => {
    audio.volume = e.target.value / 100;
  };
  $("#p-vol").onchange = saveSettings;
}

function renderFx() {
  const el = $("#fx"),
    list = S.cfg.effects || [];
  if (list.length < 2) {
    el.classList.add("hidden");
    return;
  }
  el.classList.remove("hidden");
  el.innerHTML = list
    .map(
      (e) =>
        `<button data-e="${esc(e)}" class="${e === S.effect ? "on" : ""}">${esc(e)}</button>`,
    )
    .join("");
  el.querySelectorAll("button").forEach(
    (b) =>
      (b.onclick = () => {
        tick();
        S.effect = b.dataset.e;
        $("#bars").classList.toggle("on", S.effect === "cinema");
        post("camEffect", { effect: S.effect });
        saveSettings();
        renderFx();
      }),
  );
}

/* ---------- setup ---------- */
function setup(data) {
  const first = !S.cfg.preset;
  S.cfg = data.cfg;
  S.chars = data.chars;
  S.world = data.world;
  S.sel = null;
  document.documentElement.style.setProperty("--accent", S.cfg.accent);
  $("#app").dataset.preset = S.cfg.preset;
  $("#t-title").textContent = t("title");
  $("#t-sub").textContent = t("subtitle");
  $("#t-spawn").textContent = t("spawnTitle");
  $("#t-spawn-sub").textContent = t("spawnSub");

  if (first) {
    S.effect = S.cfg.settings.effect || "none";
    S.track = Math.max(0, (S.cfg.settings.track || 1) - 1);
    audio.volume = Math.min(1, Math.max(0, S.cfg.settings.volume ?? 0.25));
    $("#bars").classList.toggle("on", S.effect === "cinema");
    if (S.cfg.music && S.cfg.music.enabled && S.cfg.music.tracks.length)
      loadTrack(S.track, true);
  }
  renderPlayer();
  renderFx();
  renderSlots();
  $("#detail").classList.add("hidden");
  $("#detail").classList.remove("show");
  $("#stage-select").classList.remove("hidden");
  $("#stage-spawn").classList.add("hidden");
  closeModal();
  $("#app").classList.remove("hidden");
}

/* ---------- slotovi ---------- */
function renderSlots() {
  const box = $("#slots"),
    world = $("#world");
  box.innerHTML = "";
  world.innerHTML = "";
  const interactive = S.cfg.preset === "interactive";

  for (let i = 1; i <= S.cfg.maxSlots; i++) {
    const ch = S.chars.find((c) => c.slot === i);
    const locked = i > S.cfg.slots;
    if (interactive) {
      addTag(world, i, ch, locked);
      continue;
    }

    const el = document.createElement("div");
    if (locked) {
      el.className = "card locked";
      el.innerHTML = `<div class="av mute">${ic("lock")}</div><div><b>${esc(t("locked"))}</b><small>${esc(t("locked_hint"))}</small></div><span class="slotno">#${i}</span>`;
      el.onclick = () => tick(220);
    } else if (ch) {
      el.className = "card" + (S.sel === ch.id ? " sel" : "");
      el.innerHTML = `<div class="av ${ch.gender === "f" ? "f" : ""}">${esc(initials(ch))}</div><div><b>${esc(ch.firstname)} ${esc(ch.lastname)}</b><small>${esc(ch.job || "")}</small></div><span class="slotno">#${i}</span>`;
      el.onclick = () => selectChar(ch);
    } else {
      el.className = "card empty";
      el.innerHTML = `<div class="av mute">${ic("plus")}</div><div><b>${esc(t("create"))}</b><small>${esc(t("empty"))}</small></div><span class="slotno">#${i}</span>`;
      el.onclick = () => startCreate();
    }
    box.appendChild(el);
  }
}

function addTag(world, i, ch, locked) {
  const pos = S.world && S.world[i];
  if (!pos) return;
  const el = document.createElement("div");
  el.style.left = pos.x * 100 + "%";
  el.style.top = pos.y * 100 + "%";
  el.style.animationDelay = i * 70 + "ms";
  if (locked) {
    el.className = "tag locked";
    el.innerHTML = `<div class="pill">${ic("lock")}<div>${esc(t("locked"))}<small>${esc(t("locked_hint"))}</small></div></div>`;
    el.onclick = () => tick(220);
  } else if (ch) {
    el.className = "tag" + (S.sel === ch.id ? " sel" : "");
    el.innerHTML = `<div class="pill"><span class="dot"></span><div>${esc(ch.firstname)} ${esc(ch.lastname)}<small>${esc(ch.job || "")}</small></div></div>`;
    el.onclick = () => selectChar(ch);
  } else {
    el.className = "tag empty";
    el.innerHTML = `<div class="pill">${ic("plus")}<div>${esc(t("create"))}<small>#${i}</small></div></div>`;
    el.onclick = () => startCreate();
  }
  world.appendChild(el);
}

function startCreate() {
  tick(640);
  S.sel = null;
  renderSlots();
  $("#detail").classList.add("hidden");
  $("#detail").classList.remove("show");
  post("empty");
  openCreate();
}

function selectChar(ch) {
  tick(560);
  S.sel = ch.id;
  renderSlots();
  post("select", { id: ch.id });
  const d = $("#detail");
  d.classList.remove("hidden");
  d.classList.add("show");
  d.innerHTML = `
    <div class="info">
      <h2>${esc(ch.firstname)} ${esc(ch.lastname)}</h2><p class="muted" style="margin-bottom:14px">#${ch.slot}</p>
      <div class="row"><span>${esc(t("dob"))}</span><span>${esc(ch.dob)}</span></div>
      <div class="row"><span>${esc(t("gender"))}</span><span>${esc(ch.gender === "f" ? t("female") : t("male"))}</span></div>
      <div class="row"><span>${esc(t("job"))}</span><span>${esc(ch.job || "-")}</span></div>
      <div class="row"><span>${esc(t("cash"))}</span><span>${money(ch.cash)}</span></div>
      <div class="row"><span>${esc(t("bank"))}</span><span>${money(ch.bank)}</span></div>
    </div>
    <div class="btns">
      <button class="primary" id="b-play">${ic("play")} ${esc(t("play"))}</button>
      ${S.cfg.canDelete ? `<button class="danger" id="b-del">${ic("trash")} ${esc(t("delete"))}</button>` : ""}
    </div>`;
  $("#b-play").onclick = () => {
    tick(740, 0.12);
    post("play", { id: ch.id });
  };
  const del = $("#b-del");
  if (del) del.onclick = () => confirmDelete(ch);
}

/* ---------- modal ---------- */
function openModal(html) {
  $("#modal-box").innerHTML = html;
  $("#modal").classList.remove("hidden");
}
function closeModal() {
  $("#modal").classList.add("hidden");
}

function confirmDelete(ch) {
  openModal(`<h2>${esc(t("deleteQ"))}</h2><p class="muted" style="margin-top:8px">${esc(ch.firstname)} ${esc(ch.lastname)}</p>
    <div class="btns"><button class="ghost" id="m-no">${esc(t("cancel"))}</button><button class="danger" id="m-yes">${ic("trash")} ${esc(t("delete"))}</button></div>`);
  $("#m-no").onclick = closeModal;
  $("#m-yes").onclick = async () => {
    closeModal();
    const r = await post("delete", { id: ch.id });
    if (!r || !r.ok) toast("err_gen");
  };
}

const spent = () =>
  (S.cfg.items || []).reduce(
    (a, it) => a + it.price * (S.cart[it.name] || 0),
    0,
  );

function openCreate() {
  S.cart = {};
  const { minYear, maxYear } = S.cfg.birth;
  const nats = S.cfg.nationalities
    .map((n) => `<option>${esc(n)}</option>`)
    .join("");
  const hasItems = (S.cfg.items || []).length > 0;
  openModal(`
    <h2>${esc(t("create"))}</h2>
    <div class="grid">
      <div><label>${esc(t("firstname"))}</label><input id="f-fn" maxlength="16" autocomplete="off"></div>
      <div><label>${esc(t("lastname"))}</label><input id="f-ln" maxlength="16" autocomplete="off"></div>
      <div><label>${esc(t("dob"))}</label><input id="f-dob" type="date" min="${minYear}-01-01" max="${maxYear}-12-31" value="${maxYear - 20}-01-01"></div>
      <div><label>${esc(t("nationality"))}</label><select id="f-nat">${nats}</select></div>
      <div><label>${esc(t("gender"))}</label><select id="f-gen"><option value="m">${esc(t("male"))}</option><option value="f">${esc(t("female"))}</option></select></div>
      <div><label>${esc(t("height"))}</label><input id="f-h" type="number" min="120" max="220" value="175"></div>
    </div>
    ${
      hasItems
        ? `<label>${esc(t("startItems"))}</label><div class="items" id="items"></div>
      <div class="budget"><span>${esc(t("budget"))}</span><span id="bud"></span></div>
      <div class="budget-bar"><i id="bud-bar"></i></div>`
        : ""
    }
    <div class="btns"><button class="ghost" id="m-back">${ic("back")} ${esc(t("back"))}</button><button class="primary" id="m-ok">${esc(t("confirm"))}</button></div>`);

  if (hasItems) {
    const box = $("#items");
    S.cfg.items.forEach((it) => {
      const d = document.createElement("div");
      d.className = "item";
      d.innerHTML = `<b>${esc(it.label)}</b><small>${money(it.price)}</small>
        <div class="qty"><button data-d="-1">−</button><span>0</span><button data-d="1">+</button></div>`;
      d.querySelectorAll("button").forEach(
        (b) =>
          (b.onclick = () => {
            const dir = Number(b.dataset.d),
              cur = S.cart[it.name] || 0,
              nx = cur + dir;
            if (nx < 0 || nx > it.max) return;
            if (dir > 0 && spent() + it.price > S.cfg.budget) return;
            tick(dir > 0 ? 700 : 420);
            S.cart[it.name] = nx;
            d.querySelector("span").textContent = nx;
            updBudget();
          }),
      );
      box.appendChild(d);
    });
    updBudget();
  }
  $("#m-back").onclick = closeModal;
  $("#m-ok").onclick = submitCreate;
  $("#f-fn").focus();
}
function updBudget() {
  const b = $("#bud");
  if (!b) return;
  b.textContent = `${money(S.cfg.budget - spent())} / ${money(S.cfg.budget)}`;
  $("#bud-bar").style.width = 100 - (spent() / S.cfg.budget) * 100 + "%";
}

let submitting = false;
async function submitCreate() {
  if (submitting) return;
  submitting = true;
  const data = {
    firstname: $("#f-fn").value,
    lastname: $("#f-ln").value,
    dob: $("#f-dob").value,
    nationality: $("#f-nat").value,
    gender: $("#f-gen").value,
    height: Number($("#f-h").value),
  };
  const r = await post("create", { data, items: S.cart });
  submitting = false;
  if (r && !r.ok) toast(r.err || "err_gen");
}

/* ---------- spawn ---------- */
function spawnStage(list) {
  $("#stage-select").classList.add("hidden");
  $("#stage-spawn").classList.remove("hidden");
  const box = $("#spawns");
  box.innerHTML = "";
  list.forEach((s, i) => {
    const el = document.createElement("div");
    el.className = "spawn";
    el.style.animationDelay = i * 80 + "ms";
    el.innerHTML = `${ic("pin")} ${esc(s.label)}`;
    el.onmouseenter = () => {
      tick(500, 0.04);
      post("previewSpawn", { index: i });
    };
    el.onclick = () => {
      tick(740, 0.12);
      post("spawn", { index: i });
    };
    box.appendChild(el);
  });
  post("previewSpawn", { index: 0 });
}

/* ---------- tastatura ---------- */
document.addEventListener("keydown", (e) => {
  if ($("#app").classList.contains("hidden")) return;
  const typing = ["INPUT", "SELECT"].includes(document.activeElement.tagName);
  if (e.key === "Escape") return closeModal();
  if (typing || !$("#modal").classList.contains("hidden")) return;
  if (/^[1-9]$/.test(e.key)) {
    const ch = S.chars.find((c) => c.slot === Number(e.key));
    if (ch) selectChar(ch);
  }
  if (e.key === "Enter" && S.sel) {
    tick(740, 0.12);
    post("play", { id: S.sel });
  }
});

// zameni postojeći handler na dnu fajla
window.addEventListener("message", (e) => {
  const { action, data } = e.data;
  if (action === "open" || action === "refresh") setup(data);
  else if (action === "spawnStage") spawnStage(data);
  else if (action === "close") {
    audio.pause();
    $("#app").classList.add("hidden");
  }
});
