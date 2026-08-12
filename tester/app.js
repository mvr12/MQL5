const DAY_KEYS = [
  ["monday", "دوشنبه", true],
  ["tuesday", "سه‌شنبه", true],
  ["wednesday", "چهارشنبه", true],
  ["thursday", "پنجشنبه", true],
  ["friday", "جمعه", true],
  ["saturday", "شنبه", false],
  ["sunday", "یکشنبه", false],
];

const SCENARIOS = [
  {
    id: "and-buy-win",
    title: "AND خرید → موفق",
    desc: "هر دو BUY، Close دو کندل بعد بالاتر",
  },
  {
    id: "and-sell-win",
    title: "AND فروش → موفق",
    desc: "هر دو SELL، Close دو کندل بعد پایین‌تر",
  },
  {
    id: "one-side",
    title: "فقط یکی سیگنال می‌دهد",
    desc: "نباید سیگنال ترکیبی صادر شود",
  },
  {
    id: "conflict",
    title: "تعارض خرید/فروش",
    desc: "یکی BUY و دیگری SELL → بدون سیگنال",
  },
  {
    id: "weekend",
    title: "فیلتر آخر هفته",
    desc: "سیگنال شنبه باید حذف شود",
  },
  {
    id: "hours",
    title: "فیلتر ساعت ۹–۱۲",
    desc: "سیگنال ۱۴:۰۰ نباید شمارش شود",
  },
  {
    id: "overnight",
    title: "بازه شبانه ۲۲–۰۲",
    desc: "نیمه‌شب مجاز، ظهر غیرمجاز",
  },
  {
    id: "streaks",
    title: "استریک موفقیت/شکست",
    desc: "برد، برد، باخت → استریک فعلی -1",
  },
  {
    id: "recent",
    title: "کندل در حال تشکیل",
    desc: "سیگنال‌های خیلی جدید در آمار نیستند",
  },
];

let activeScenario = "and-buy-win";

function pad(n) {
  return String(n).padStart(2, "0");
}

function fmtTime(d) {
  return `${pad(d.getMonth() + 1)}/${pad(d.getDate())} ${pad(d.getHours())}:${pad(d.getMinutes())}`;
}

function makeBar(time, close, extras = {}) {
  return {
    time,
    open: extras.open ?? close,
    high: extras.high ?? close + 0.8,
    low: extras.low ?? close - 0.8,
    close,
    i1Buy: extras.i1Buy ?? EMPTY_VALUE,
    i1Sell: extras.i1Sell ?? EMPTY_VALUE,
    i2Buy: extras.i2Buy ?? EMPTY_VALUE,
    i2Sell: extras.i2Sell ?? EMPTY_VALUE,
  };
}

function hourlySeries(start, count, priceFn) {
  const bars = [];
  for (let i = 0; i < count; i++) {
    const t = new Date(start.getTime() + i * 3600 * 1000);
    const close = priceFn(i, t);
    bars.push(makeBar(t, close));
  }
  return bars;
}

function buildScenario(id, cfg) {
  const start = new Date(2026, 7, 3, 0, 0, 0); // Monday 2026-08-03
  let bars = hourlySeries(start, 36, (i) => 100 + Math.sin(i / 3) * 1.2 + i * 0.05);

  const mark = (hourOffset, extras, close) => {
    const idx = hourOffset;
    if (idx < 0 || idx >= bars.length) return;
    const prev = bars[idx];
    bars[idx] = makeBar(prev.time, close ?? prev.close, extras);
  };

  if (id === "and-buy-win") {
    mark(10, { i1Buy: 1, i2Buy: 1 }, 100);
    mark(12, {}, 102);
  } else if (id === "and-sell-win") {
    mark(10, { i1Sell: 1, i2Sell: 1 }, 102);
    mark(12, {}, 99.5);
  } else if (id === "one-side") {
    mark(8, { i1Buy: 1 }, 100);
    mark(10, { i2Buy: 1 }, 100);
    mark(12, { i1Sell: 1 }, 101);
  } else if (id === "conflict") {
    mark(10, { i1Buy: 1, i2Sell: 1 }, 100);
    mark(12, {}, 104);
  } else if (id === "weekend") {
    bars = hourlySeries(new Date(2026, 7, 7, 0, 0, 0), 40, (i) => 100 + i * 0.1);
    // Saturday 2026-08-08 10:00 is +34 hours from Friday 00:00
    const satIdx = bars.findIndex((b) => b.time.getDay() === 6 && b.time.getHours() === 10);
    if (satIdx >= 0) {
      bars[satIdx] = makeBar(bars[satIdx].time, 100, { i1Buy: 1, i2Buy: 1 });
      if (bars[satIdx + 2]) bars[satIdx + 2] = makeBar(bars[satIdx + 2].time, 110);
    }
    const friIdx = bars.findIndex((b) => b.time.getDay() === 5 && b.time.getHours() === 10);
    if (friIdx >= 0) {
      bars[friIdx] = makeBar(bars[friIdx].time, 100, { i1Buy: 1, i2Buy: 1 });
      if (bars[friIdx + 2]) bars[friIdx + 2] = makeBar(bars[friIdx + 2].time, 103);
    }
  } else if (id === "hours") {
    cfg.startHour = 9;
    cfg.startMinute = 0;
    cfg.endHour = 12;
    cfg.endMinute = 0;
    document.getElementById("startTime").value = "09:00";
    document.getElementById("endTime").value = "12:00";
    mark(10, { i1Buy: 1, i2Buy: 1 }, 100); // 10:00 in
    mark(12, {}, 103);
    mark(14, { i1Sell: 1, i2Sell: 1 }, 103); // 14:00 out
    mark(16, {}, 99);
  } else if (id === "overnight") {
    cfg.startHour = 22;
    cfg.startMinute = 0;
    cfg.endHour = 2;
    cfg.endMinute = 0;
    document.getElementById("startTime").value = "22:00";
    document.getElementById("endTime").value = "02:00";
    mark(22, { i1Buy: 1, i2Buy: 1 }, 100); // 22:00 allowed
    mark(24, {}, 101.5); // next day 00:00 + 2h from 22 = hour 24
    mark(12, { i1Sell: 1, i2Sell: 1 }, 102); // noon blocked
    mark(14, {}, 98);
  } else if (id === "streaks") {
    mark(5, { i1Buy: 1, i2Buy: 1 }, 100);
    mark(7, {}, 101);
    mark(8, { i1Buy: 1, i2Buy: 1 }, 100);
    mark(10, {}, 102);
    mark(11, { i1Buy: 1, i2Buy: 1 }, 100);
    mark(13, {}, 99);
  } else if (id === "recent") {
    const n = bars.length;
    // shift 0 forming, shift 1 and 2 too recent for N=2 stats, shift 3 counted
    bars[n - 1] = makeBar(bars[n - 1].time, 120, { i1Buy: 1, i2Buy: 1 });
    bars[n - 2] = makeBar(bars[n - 2].time, 119, { i1Buy: 1, i2Buy: 1 });
    bars[n - 3] = makeBar(bars[n - 3].time, 118, { i1Buy: 1, i2Buy: 1 });
    bars[n - 4] = makeBar(bars[n - 4].time, 110, { i1Buy: 1, i2Buy: 1 });
  }

  return { bars, cfg };
}

function readConfig() {
  const start = document.getElementById("startTime").value.split(":");
  const end = document.getElementById("endTime").value.split(":");
  const cfg = {
    barsForward: Number(document.getElementById("barsForward").value) || 2,
    ignoreZero: document.getElementById("ignoreZero").checked,
    useTimeFilter: document.getElementById("useTimeFilter").checked,
    startHour: Number(start[0]),
    startMinute: Number(start[1]),
    endHour: Number(end[0]),
    endMinute: Number(end[1]),
  };
  DAY_KEYS.forEach(([key]) => {
    cfg[key] = document.getElementById("day-" + key).checked;
  });
  return cfg;
}

function renderStats(cfg, stats) {
  const tf = cfg.useTimeFilter
    ? `ENABLED (${pad(cfg.startHour)}:${pad(cfg.startMinute)} - ${pad(cfg.endHour)}:${pad(cfg.endMinute)})`
    : "DISABLED";
  document.getElementById("stats").textContent = [
    "========================================",
    "   STRATEGY COMBINER v1 (Custom Ind.)",
    "========================================",
    "Indicator 1 : Custom Slot 1",
    "BUY Buffer  : user-defined | SELL Buffer: user-defined",
    "",
    "Indicator 2 : Custom Slot 2",
    "BUY Buffer  : user-defined | SELL Buffer: user-defined",
    "",
    "Logic Mode  : AND",
    `Outcome Bars: ${cfg.barsForward} (N-Bar Close)`,
    `Time Filter : ${tf}`,
    "----------------------------------------",
    `TOTAL SIGNALS       : ${stats.total}`,
    `SUCCESSFUL SIGNALS  : ${stats.successful}`,
    `FAILED SIGNALS      : ${stats.failed}`,
    `SUCCESS RATE        : ${successRate(stats).toFixed(2)}%`,
    "----------------------------------------",
    `MAX SUCCESS STREAK  : ${stats.maxWin}`,
    `MAX FAILURE STREAK  : ${stats.maxLoss}`,
    `CURRENT STREAK      : ${currentStreakText(stats)}`,
    "========================================",
  ].join("\n");
}

function renderLog(events) {
  const box = document.getElementById("log");
  if (!events.length) {
    box.innerHTML = '<div class="skip">هیچ سیگنال ترکیبی شمرده نشد.</div>';
    return;
  }
  box.innerHTML = events
    .map((e) => {
      const dir = e.signal === 1 ? '<span class="buy">BUY</span>' : '<span class="sell">SELL</span>';
      const res = e.success
        ? '<span class="ok">SUCCESS</span>'
        : '<span class="bad">FAILURE</span>';
      return `<div class="row-item"><span>${fmtTime(e.time)}</span>${dir}<span>Close ${e.signalClose.toFixed(2)} → ${e.futureClose.toFixed(2)}</span>${res}</div>`;
    })
    .join("");
}

function drawChart(bars, drawn) {
  const canvas = document.getElementById("chart");
  const ctx = canvas.getContext("2d");
  const w = canvas.width;
  const h = canvas.height;
  ctx.clearRect(0, 0, w, h);
  ctx.fillStyle = "#0a1020";
  ctx.fillRect(0, 0, w, h);

  const padL = 50;
  const padR = 16;
  const padT = 18;
  const padB = 28;
  const highs = bars.map((b) => b.high);
  const lows = bars.map((b) => b.low);
  const minP = Math.min(...lows) - 1.5;
  const maxP = Math.max(...highs) + 1.5;
  const xStep = (w - padL - padR) / bars.length;
  const yOf = (p) => padT + ((maxP - p) / (maxP - minP)) * (h - padT - padB);

  ctx.strokeStyle = "#1c2744";
  ctx.lineWidth = 1;
  for (let i = 0; i < 5; i++) {
    const y = padT + ((h - padT - padB) * i) / 4;
    ctx.beginPath();
    ctx.moveTo(padL, y);
    ctx.lineTo(w - padR, y);
    ctx.stroke();
    const price = maxP - ((maxP - minP) * i) / 4;
    ctx.fillStyle = "#7d8bb0";
    ctx.font = "11px sans-serif";
    ctx.textAlign = "right";
    ctx.fillText(price.toFixed(2), padL - 6, y + 3);
  }

  bars.forEach((b, i) => {
    const x = padL + i * xStep + xStep / 2;
    const up = b.close >= b.open;
    ctx.strokeStyle = up ? "#7CFF6B" : "#ff5b6e";
    ctx.fillStyle = up ? "#7CFF6B" : "#ff5b6e";
    ctx.beginPath();
    ctx.moveTo(x, yOf(b.high));
    ctx.lineTo(x, yOf(b.low));
    ctx.stroke();
    const bodyTop = yOf(Math.max(b.open, b.close));
    const bodyBot = yOf(Math.min(b.open, b.close));
    ctx.fillRect(x - Math.max(2, xStep * 0.28), bodyTop, Math.max(4, xStep * 0.56), Math.max(1, bodyBot - bodyTop));
  });

  drawn.forEach((e) => {
    const i = bars.length - 1 - e.shift;
    const x = padL + i * xStep + xStep / 2;
    if (e.signal === 1) {
      ctx.fillStyle = "#7CFF6B";
      ctx.beginPath();
      ctx.moveTo(x, yOf(e.low) + 14);
      ctx.lineTo(x - 5, yOf(e.low) + 24);
      ctx.lineTo(x + 5, yOf(e.low) + 24);
      ctx.fill();
    } else {
      ctx.fillStyle = "#ff5b6e";
      ctx.beginPath();
      ctx.moveTo(x, yOf(e.high) - 14);
      ctx.lineTo(x - 5, yOf(e.high) - 24);
      ctx.lineTo(x + 5, yOf(e.high) - 24);
      ctx.fill();
    }
    if (e.success === true) {
      ctx.fillStyle = "#5ce1e6";
      ctx.fillText("✓", x - 4, e.signal === 1 ? yOf(e.low) + 36 : yOf(e.high) - 28);
    } else if (e.success === false) {
      ctx.fillStyle = "#ffb020";
      ctx.fillText("×", x - 3, e.signal === 1 ? yOf(e.low) + 36 : yOf(e.high) - 28);
    }
  });

  ctx.fillStyle = "#93a0c2";
  ctx.font = "11px sans-serif";
  ctx.textAlign = "left";
  ctx.fillText("سبز = BUY ترکیبی   قرمز = SELL ترکیبی   آبی = موفق   نارنجی = شکست   کندل آخر = در حال تشکیل", padL, h - 8);
}

function runActive() {
  let cfg = readConfig();
  const built = buildScenario(activeScenario, cfg);
  cfg = built.cfg;
  const stats = runCombiner(built.bars, cfg);
  const drawn = collectDrawn(built.bars, cfg);
  renderStats(cfg, stats);
  renderLog(stats.events);
  drawChart(built.bars, drawn);
}

function almost(a, b, eps = 1e-9) {
  return Math.abs(a - b) < eps;
}

function runBrowserTests() {
  const tests = [];
  const add = (name, fn) => {
    try {
      fn();
      tests.push({ name, ok: true, detail: "قبول" });
    } catch (err) {
      tests.push({ name, ok: false, detail: err.message });
    }
  };
  const assert = (cond, msg) => {
    if (!cond) throw new Error(msg);
  };

  add("هر دو BUY → سیگنال خرید", () => {
    const s = getCombinedSignal(
      { i1Buy: 1, i1Sell: EMPTY_VALUE, i2Buy: 1, i2Sell: EMPTY_VALUE },
      { ignoreZero: true }
    );
    assert(s === 1, "expected BUY, got " + s);
  });
  add("هر دو SELL → سیگنال فروش", () => {
    const s = getCombinedSignal(
      { i1Buy: EMPTY_VALUE, i1Sell: 1, i2Buy: EMPTY_VALUE, i2Sell: 1 },
      { ignoreZero: true }
    );
    assert(s === -1, "expected SELL");
  });
  add("فقط یک اندیکاتور BUY → بدون سیگنال", () => {
    const s = getCombinedSignal(
      { i1Buy: 1, i1Sell: EMPTY_VALUE, i2Buy: EMPTY_VALUE, i2Sell: EMPTY_VALUE },
      { ignoreZero: true }
    );
    assert(s === 0, "expected NONE");
  });
  add("تعارض BUY و SELL → بدون سیگنال", () => {
    const s = getCombinedSignal(
      { i1Buy: 1, i1Sell: EMPTY_VALUE, i2Buy: EMPTY_VALUE, i2Sell: 1 },
      { ignoreZero: true }
    );
    assert(s === 0, "expected NONE");
  });
  add("مقدار صفر با IgnoreZero نادیده گرفته شود", () => {
    assert(!isSignalValue(0, true), "zero should be ignored");
    assert(isSignalValue(0, false), "zero should count when flag is off");
  });
  add("EMPTY / NaN سیگنال نیستند", () => {
    assert(!isSignalValue(EMPTY_VALUE, true), "EMPTY");
    assert(!isSignalValue(Number.NaN, true), "NaN");
  });
  add("BUY موفق اگر Close[N] > Close سیگنال", () => {
    const start = new Date(2026, 7, 3, 0, 0, 0);
    const bars = hourlySeries(start, 20, () => 100);
    bars[10] = makeBar(bars[10].time, 100, { i1Buy: 1, i2Buy: 1 });
    bars[12] = makeBar(bars[12].time, 101);
    const cfg = {
      barsForward: 2,
      ignoreZero: true,
      useTimeFilter: false,
      startHour: 0,
      startMinute: 0,
      endHour: 23,
      endMinute: 59,
      monday: true,
      tuesday: true,
      wednesday: true,
      thursday: true,
      friday: true,
      saturday: true,
      sunday: true,
    };
    const stats = runCombiner(bars, cfg);
    assert(stats.total === 1 && stats.successful === 1, JSON.stringify(stats));
  });
  add("BUY مساوی Close = شکست", () => {
    const start = new Date(2026, 7, 3, 0, 0, 0);
    const bars = hourlySeries(start, 20, () => 100);
    bars[10] = makeBar(bars[10].time, 100, { i1Buy: 1, i2Buy: 1 });
    const cfg = {
      barsForward: 2,
      ignoreZero: true,
      useTimeFilter: false,
      startHour: 0, startMinute: 0, endHour: 23, endMinute: 59,
      monday: true, tuesday: true, wednesday: true, thursday: true, friday: true, saturday: true, sunday: true,
    };
    const stats = runCombiner(bars, cfg);
    assert(stats.failed === 1 && stats.successful === 0, "equal close must fail");
  });
  add("SELL موفق اگر Close[N] < Close سیگنال", () => {
    const start = new Date(2026, 7, 3, 0, 0, 0);
    const bars = hourlySeries(start, 20, () => 100);
    bars[10] = makeBar(bars[10].time, 100, { i1Sell: 1, i2Sell: 1 });
    bars[12] = makeBar(bars[12].time, 98);
    const cfg = {
      barsForward: 2,
      ignoreZero: true,
      useTimeFilter: false,
      startHour: 0, startMinute: 0, endHour: 23, endMinute: 59,
      monday: true, tuesday: true, wednesday: true, thursday: true, friday: true, saturday: true, sunday: true,
    };
    const stats = runCombiner(bars, cfg);
    assert(stats.successful === 1, "sell should succeed");
  });
  add("شنبه وقتی Saturday=false حذف شود", () => {
    const sat = new Date(2026, 7, 8, 10, 0, 0);
    const cfg = {
      useTimeFilter: true,
      startHour: 0, startMinute: 0, endHour: 23, endMinute: 59,
      monday: true, tuesday: true, wednesday: true, thursday: true, friday: true, saturday: false, sunday: false,
    };
    assert(!isAllowedTime(sat, cfg), "Saturday must be blocked");
  });
  add("بازه شبانه ۲۲:۰۰–۰۲:۰۰", () => {
    const cfg = {
      useTimeFilter: true,
      startHour: 22, startMinute: 0, endHour: 2, endMinute: 0,
      monday: true, tuesday: true, wednesday: true, thursday: true, friday: true, saturday: false, sunday: false,
    };
    assert(isAllowedTime(new Date(2026, 7, 3, 23, 0, 0), cfg), "23:00 should pass");
    assert(isAllowedTime(new Date(2026, 7, 3, 1, 0, 0), cfg), "01:00 should pass");
    assert(!isAllowedTime(new Date(2026, 7, 3, 12, 0, 0), cfg), "12:00 should fail");
  });
  add("سیگنال خیلی جدید در آمار نیاید", () => {
    const start = new Date(2026, 7, 3, 0, 0, 0);
    const bars = hourlySeries(start, 20, (i) => 100 + i);
    bars[19] = makeBar(bars[19].time, 130, { i1Buy: 1, i2Buy: 1 });
    bars[18] = makeBar(bars[18].time, 129, { i1Buy: 1, i2Buy: 1 });
    bars[17] = makeBar(bars[17].time, 128, { i1Buy: 1, i2Buy: 1 });
    const cfg = {
      barsForward: 2,
      ignoreZero: true,
      useTimeFilter: false,
      startHour: 0, startMinute: 0, endHour: 23, endMinute: 59,
      monday: true, tuesday: true, wednesday: true, thursday: true, friday: true, saturday: true, sunday: true,
    };
    const stats = runCombiner(bars, cfg);
    assert(stats.total === 0, "recent signals must wait for N closed bars, got " + stats.total);
  });
  add("استریک از قدیمی به جدید", () => {
    const start = new Date(2026, 7, 3, 0, 0, 0);
    const bars = hourlySeries(start, 20, () => 100);
    bars[5] = makeBar(bars[5].time, 100, { i1Buy: 1, i2Buy: 1 });
    bars[7] = makeBar(bars[7].time, 101);
    bars[8] = makeBar(bars[8].time, 100, { i1Buy: 1, i2Buy: 1 });
    bars[10] = makeBar(bars[10].time, 102);
    bars[11] = makeBar(bars[11].time, 100, { i1Buy: 1, i2Buy: 1 });
    bars[13] = makeBar(bars[13].time, 99);
    const cfg = {
      barsForward: 2,
      ignoreZero: true,
      useTimeFilter: false,
      startHour: 0, startMinute: 0, endHour: 23, endMinute: 59,
      monday: true, tuesday: true, wednesday: true, thursday: true, friday: true, saturday: true, sunday: true,
    };
    const stats = runCombiner(bars, cfg);
    assert(stats.total === 3, "need 3 signals");
    assert(stats.maxWin === 2, "max win 2");
    assert(stats.maxLoss === 1, "max loss 1");
    assert(currentStreakText(stats) === "-1 (FAILURE)", stats.currentLoss);
    assert(almost(successRate(stats), 200 / 3), "rate");
  });
  add("UseTimeFilter=false روز را هم رد می‌کند (رفتار فعلی کد)", () => {
    const sat = new Date(2026, 7, 8, 3, 0, 0);
    const cfg = {
      useTimeFilter: false,
      saturday: false,
      sunday: false,
      monday: true, tuesday: true, wednesday: true, thursday: true, friday: true,
      startHour: 0, startMinute: 0, endHour: 23, endMinute: 59,
    };
    assert(isAllowedTime(sat, cfg) === true, "current MQL skips day filter when time filter is off");
  });

  const box = document.getElementById("testList");
  box.innerHTML = tests
    .map(
      (t) =>
        `<div class="test ${t.ok ? "pass" : "fail"}"><b>${t.ok ? "قبول" : "رد"} — ${t.name}</b><span>${t.detail}</span></div>`
    )
    .join("");
  const passed = tests.filter((t) => t.ok).length;
  document.getElementById("testSummary").textContent = `${passed} / ${tests.length} تست قبول شد`;
  return tests;
}

function init() {
  const dayBox = document.getElementById("days");
  dayBox.innerHTML = DAY_KEYS.map(
    ([key, label, def]) =>
      `<label class="check"><input type="checkbox" id="day-${key}" ${def ? "checked" : ""} /> ${label}</label>`
  ).join("");

  const sc = document.getElementById("scenarios");
  sc.innerHTML = SCENARIOS.map(
    (s) => `<button data-id="${s.id}" class="${s.id === activeScenario ? "active" : ""}">${s.title}<br><small>${s.desc}</small></button>`
  ).join("");
  sc.addEventListener("click", (e) => {
    const btn = e.target.closest("button");
    if (!btn) return;
    activeScenario = btn.dataset.id;
    [...sc.querySelectorAll("button")].forEach((b) => b.classList.toggle("active", b === btn));
    if (activeScenario === "hours" || activeScenario === "overnight") {
      // values applied in builder
    } else {
      document.getElementById("startTime").value = "00:00";
      document.getElementById("endTime").value = "23:59";
    }
    runActive();
  });

  document.getElementById("runBtn").addEventListener("click", runActive);
  ["barsForward", "ignoreZero", "useTimeFilter", "startTime", "endTime"].forEach((id) => {
    document.getElementById(id).addEventListener("change", runActive);
  });
  dayBox.addEventListener("change", runActive);
  document.getElementById("runTestsBtn").addEventListener("click", runBrowserTests);

  runActive();
  runBrowserTests();
}

init();
