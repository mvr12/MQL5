const EMPTY_VALUE = Number.POSITIVE_INFINITY;

function isSignalValue(value, ignoreZero) {
  if (value === EMPTY_VALUE || !Number.isFinite(value)) return false;
  if (ignoreZero && value === 0) return false;
  return true;
}

function isValidTrend(value) {
  return Number.isFinite(value) && value !== EMPTY_VALUE;
}

function isAllowedDay(date, cfg) {
  const map = [
    cfg.sunday,
    cfg.monday,
    cfg.tuesday,
    cfg.wednesday,
    cfg.thursday,
    cfg.friday,
    cfg.saturday,
  ];
  return map[date.getDay()];
}

function isAllowedTime(date, cfg) {
  if (!cfg.useTimeFilter) return true;
  if (!isAllowedDay(date, cfg)) return false;
  const current = date.getHours() * 60 + date.getMinutes();
  const start = cfg.startHour * 60 + cfg.startMinute;
  const end = cfg.endHour * 60 + cfg.endMinute;
  if (start <= end) return current >= start && current <= end;
  return current >= start || current <= end;
}

function getSourceSignal(bar, cfg) {
  const use1 = cfg.useIndicator1 !== false;
  const use2 = cfg.useIndicator2 !== false;
  if (!use1 && !use2) return 0;

  let wantBuy = true;
  let wantSell = true;

  if (use1) {
    if (!isSignalValue(bar.i1Buy, cfg.ignoreZero)) wantBuy = false;
    if (!isSignalValue(bar.i1Sell, cfg.ignoreZero)) wantSell = false;
  }
  if (use2) {
    if (!isSignalValue(bar.i2Buy, cfg.ignoreZero)) wantBuy = false;
    if (!isSignalValue(bar.i2Sell, cfg.ignoreZero)) wantSell = false;
  }

  if (wantBuy && !wantSell) return 1;
  if (wantSell && !wantBuy) return -1;
  if (wantBuy) return 1;
  if (wantSell) return -1;
  return 0;
}

function getCombinedSignal(bar, cfg) {
  return getSourceSignal(bar, cfg);
}

function getCompareValue(bar, signal, cfg) {
  if (cfg.trendCompare === "open") return bar.open;
  if (cfg.trendCompare === "high") return bar.high;
  if (cfg.trendCompare === "low") return bar.low;
  if (cfg.trendCompare === "signal") {
    const vals = [];
    if (signal === 1) {
      if (cfg.useIndicator1 !== false && isSignalValue(bar.i1Buy, cfg.ignoreZero)) vals.push(bar.i1Buy);
      if (cfg.useIndicator2 !== false && isSignalValue(bar.i2Buy, cfg.ignoreZero)) vals.push(bar.i2Buy);
    } else if (signal === -1) {
      if (cfg.useIndicator1 !== false && isSignalValue(bar.i1Sell, cfg.ignoreZero)) vals.push(bar.i1Sell);
      if (cfg.useIndicator2 !== false && isSignalValue(bar.i2Sell, cfg.ignoreZero)) vals.push(bar.i2Sell);
    }
    if (vals.length) return vals.reduce((a, b) => a + b, 0) / vals.length;
  }
  return bar.close;
}

function isTrendConfirmed(bar, signal, cfg) {
  if (!cfg.useTrend) return true;
  if (!isValidTrend(bar.trend)) return false;
  const ref = getCompareValue(bar, signal, cfg);
  const above = ref > bar.trend;
  const below = ref < bar.trend;
  if (cfg.buyAboveSellBelow !== false) {
    if (signal === 1) return above;
    if (signal === -1) return below;
  } else {
    if (signal === 1) return below;
    if (signal === -1) return above;
  }
  return false;
}

function getFinalSignal(bar, cfg) {
  const signal = getSourceSignal(bar, cfg);
  if (signal === 0) return 0;
  if (!isTrendConfirmed(bar, signal, cfg)) return 0;
  return signal;
}

function seriesBar(bars, shift) {
  return bars[bars.length - 1 - shift];
}

function runCombiner(bars, cfg) {
  const stats = {
    total: 0,
    successful: 0,
    failed: 0,
    currentWin: 0,
    currentLoss: 0,
    maxWin: 0,
    maxLoss: 0,
    filteredByTrend: 0,
    events: [],
  };

  if (bars.length < cfg.barsForward + 10) return stats;

  const oldest = bars.length - 1;
  const newestAllowed = cfg.barsForward + 1;

  for (let shift = oldest; shift >= newestAllowed; shift--) {
    const bar = seriesBar(bars, shift);
    if (!isAllowedTime(bar.time, cfg)) continue;
    const source = getSourceSignal(bar, cfg);
    if (source === 0) continue;
    if (!isTrendConfirmed(bar, source, cfg)) {
      stats.filteredByTrend += 1;
      continue;
    }
    const futureShift = shift - cfg.barsForward;
    if (futureShift < 1) continue;
    const future = seriesBar(bars, futureShift);
    let success = false;
    if (source === 1) success = future.close > bar.close;
    if (source === -1) success = future.close < bar.close;

    stats.total += 1;
    if (success) {
      stats.successful += 1;
      stats.currentWin += 1;
      stats.currentLoss = 0;
      if (stats.currentWin > stats.maxWin) stats.maxWin = stats.currentWin;
    } else {
      stats.failed += 1;
      stats.currentLoss += 1;
      stats.currentWin = 0;
      if (stats.currentLoss > stats.maxLoss) stats.maxLoss = stats.currentLoss;
    }

    stats.events.push({
      shift,
      time: bar.time,
      signal: source,
      signalClose: bar.close,
      futureShift,
      futureClose: future.close,
      success,
      counted: true,
    });
  }
  return stats;
}

function collectDrawn(bars, cfg) {
  const drawn = [];
  const oldest = bars.length - 1;
  for (let shift = oldest; shift >= 1; shift--) {
    const bar = seriesBar(bars, shift);
    if (!isAllowedTime(bar.time, cfg)) continue;
    const signal = getFinalSignal(bar, cfg);
    if (signal === 0) continue;
    const futureShift = shift - cfg.barsForward;
    let success = null;
    let futureClose = null;
    if (futureShift >= 1) {
      const future = seriesBar(bars, futureShift);
      futureClose = future.close;
      success = signal === 1 ? future.close > bar.close : future.close < bar.close;
    }
    drawn.push({
      shift,
      time: bar.time,
      signal,
      signalClose: bar.close,
      futureShift: futureShift >= 1 ? futureShift : null,
      futureClose,
      success,
      counted: futureShift >= 1,
      high: bar.high,
      low: bar.low,
    });
  }
  return drawn;
}

function currentStreakText(stats) {
  if (stats.currentWin > 0) return `+${stats.currentWin} (SUCCESS)`;
  if (stats.currentLoss > 0) return `-${stats.currentLoss} (FAILURE)`;
  return "0";
}

function successRate(stats) {
  if (stats.total <= 0) return 0;
  return (100 * stats.successful) / stats.total;
}

if (typeof module !== "undefined") {
  module.exports = {
    EMPTY_VALUE,
    isSignalValue,
    isAllowedTime,
    getCombinedSignal,
    getFinalSignal,
    runCombiner,
    collectDrawn,
    currentStreakText,
    successRate,
  };
}
