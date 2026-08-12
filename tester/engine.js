const EMPTY_VALUE = Number.POSITIVE_INFINITY;

function isSignalValue(value, ignoreZero) {
  if (value === EMPTY_VALUE || !Number.isFinite(value)) return false;
  if (ignoreZero && value === 0) return false;
  return true;
}

function isAllowedDay(date, cfg) {
  // JS: 0 Sunday ... 6 Saturday  (same as MQL)
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

function getCombinedSignal(bar, cfg) {
  const i1Buy = isSignalValue(bar.i1Buy, cfg.ignoreZero);
  const i1Sell = isSignalValue(bar.i1Sell, cfg.ignoreZero);
  const i2Buy = isSignalValue(bar.i2Buy, cfg.ignoreZero);
  const i2Sell = isSignalValue(bar.i2Sell, cfg.ignoreZero);

  if (i1Buy && i2Buy && !i1Sell && !i2Sell) return 1;
  if (i1Sell && i2Sell && !i1Buy && !i2Buy) return -1;
  if (i1Buy && i2Buy) return 1;
  if (i1Sell && i2Sell) return -1;
  return 0;
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
    events: [],
  };

  if (bars.length < cfg.barsForward + 10) return stats;

  const oldest = bars.length - 1;
  const newestAllowed = cfg.barsForward + 1;

  for (let shift = oldest; shift >= newestAllowed; shift--) {
    const bar = seriesBar(bars, shift);
    if (!isAllowedTime(bar.time, cfg)) continue;
    const signal = getCombinedSignal(bar, cfg);
    if (signal === 0) continue;
    const futureShift = shift - cfg.barsForward;
    if (futureShift < 1) continue;
    const future = seriesBar(bars, futureShift);
    let success = false;
    if (signal === 1) success = future.close > bar.close;
    if (signal === -1) success = future.close < bar.close;

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
      signal,
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
    const signal = getCombinedSignal(bar, cfg);
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
    runCombiner,
    collectDrawn,
    currentStreakText,
    successRate,
  };
}
