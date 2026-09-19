function parseCatalog(raw) {
  var text = String(raw || "")
  if (text.length > 524288) return { ok: false, lastError: "Catalog too large" }
  try {
    var data = JSON.parse(text.trim())
  } catch (e) {
    return { ok: false, lastError: "Could not parse catalog" }
  }
  if (!data || typeof data !== "object" || !Array.isArray(data.tracks))
    return { ok: false, lastError: "Catalog is empty" }
  var tracks = []
  var idRe = /^[A-Za-z0-9_-]{8,16}$/
  for (var i = 0; i < data.tracks.length && tracks.length < 1500; i++) {
    var track = data.tracks[i]
    if (!track || !track.id) continue
    var id = String(track.id)
    if (!idRe.test(id)) continue
    var title = String(track.title || "Untitled")
    if (title.length > 200) title = title.substring(0, 200)
    tracks.push({
      id: id,
      title: title,
      duration: Number(track.duration || 0)
    })
  }
  if (tracks.length === 0) return { ok: false, lastError: "No playable tracks" }
  return {
    ok: true,
    channel: String(data.channel || ""),
    fetchedAt: Number(data.fetchedAt || 0),
    live: parseLiveTrack(data.live),
    tracks: tracks
  }
}

function parseLiveTrack(obj) {
  if (!obj || typeof obj !== "object") return null
  if (obj.live === false) return null
  var id = String(obj.id || "")
  if (!/^[A-Za-z0-9_-]{8,16}$/.test(id)) return null
  var status = String(obj.live_status || "")
  if (status && status !== "is_live") return null
  var title = String(obj.title || "Live")
  if (title.length > 200) title = title.substring(0, 200)
  return { id: id, title: title, duration: 0, live: true }
}

function parseLivePayload(raw) {
  var text = String(raw || "").trim()
  if (!text) return null
  try {
    var data = JSON.parse(text)
  } catch (e) {
    return null
  }
  return parseLiveTrack(data)
}

function pickTrack(tracks, recentIds) {
  var list = Array.isArray(tracks) ? tracks : []
  if (list.length === 0) return null

  var recent = {}
  var history = Array.isArray(recentIds) ? recentIds : []
  for (var i = 0; i < history.length; i++) recent[String(history[i])] = true

  var pool = []
  for (var j = 0; j < list.length; j++) {
    if (!recent[list[j].id]) pool.push(list[j])
  }
  if (pool.length === 0) pool = list
  return pool[Math.floor(Math.random() * pool.length)]
}

// Random offset so tuning in lands mid-session, like a radio.
// Leaves minRemaining seconds at the end so the track does not immediately end.
function pickStartOffset(duration, minRemaining) {
  var d = Math.max(0, Math.floor(Number(duration) || 0))
  var remain = 90
  if (minRemaining !== undefined && minRemaining !== null && minRemaining !== "")
    remain = Math.max(0, Math.floor(Number(minRemaining) || 0))
  var maxStart = d - remain
  if (maxStart <= 0) return 0
  return Math.floor(Math.random() * (maxStart + 1))
}

function rememberId(recentIds, id, limit) {
  var next = []
  var value = String(id || "")
  if (value) next.push(value)
  var history = Array.isArray(recentIds) ? recentIds : []
  var cap = Math.max(1, Number(limit) || 24)
  for (var i = 0; i < history.length && next.length < cap; i++) {
    if (String(history[i]) !== value) next.push(String(history[i]))
  }
  return next
}

function snapshotTrack(track, start) {
  if (!track || !track.id) return null
  var title = String(track.title || "")
  if (title.length > 200) title = title.substring(0, 200)
  return {
    id: String(track.id),
    title: title,
    duration: Number(track.duration || 0),
    live: !!track.live,
    start: Math.max(0, Math.floor(Number(start || 0)))
  }
}

function pushHistory(history, track, start, limit) {
  var snap = snapshotTrack(track, start)
  var prev = Array.isArray(history) ? history : []
  if (!snap) return prev.slice()
  var cap = Math.max(1, Number(limit) || 20)
  var next = [snap]
  for (var i = 0; i < prev.length && next.length < cap; i++) {
    if (!prev[i] || String(prev[i].id) === snap.id) continue
    next.push(prev[i])
  }
  return next
}

function popHistory(history) {
  var prev = Array.isArray(history) ? history.slice() : []
  if (prev.length === 0) return { track: null, history: [] }
  return { track: prev[0], history: prev.slice(1) }
}

function formatDuration(seconds) {
  var s = Math.max(0, Math.round(Number(seconds) || 0))
  if (s <= 0) return ""
  var h = Math.floor(s / 3600)
  var m = Math.floor((s % 3600) / 60)
  if (h > 0) return m > 0 ? h + "h " + m + "m" : h + "h"
  if (m > 0) return m + " min"
  return s + "s"
}

function formatProgress(elapsed, duration, live) {
  if (live) return "Live now"
  var e = formatDuration(elapsed)
  var d = formatDuration(duration)
  if (e && d) return e + " into a " + d + " session"
  if (d) return d
  if (e) return e
  return ""
}

function barIcon(on, loading) {
  if (loading) return "󰔟"
  if (on) return "󰐹"
  return "󰐹"
}

function stateLabel(on, loading, title, error, paused, needsResume, live) {
  if (error && !loading) return String(error)
  if (loading) return "Tuning in…"
  if (needsResume) return "Click to resume"
  if (live && on) return title ? "Live · " + title : "Live"
  if (on && paused) return title ? "Paused · " + title : "Paused"
  if (on && title) return title
  if (on) return "On air"
  return "Off"
}

function heroMeta(on, loading, error, paused, needsResume, live) {
  if (loading) return "Tuning in…"
  if (error && on) return "Problem"
  if (needsResume) return "Was on last session"
  if (live && on) return "Live · Marc Rebillet"
  if (on && paused) return "Paused · Marc Rebillet"
  if (on) return "On air · Marc Rebillet"
  return "Off"
}

function youtubeUrl(id) {
  var videoId = String(id || "")
  if (!/^[A-Za-z0-9_-]+$/.test(videoId)) return ""
  return "https://www.youtube.com/watch?v=" + videoId
}

function pluginDirFromUrl(url) {
  var text = String(url || "")
  if (text.indexOf("file://") === 0) text = text.substring(7)
  if (text.indexOf("localhost/") === 0) text = text.substring("localhost".length)
  if (text.length > 1 && text.charAt(text.length - 1) === "/")
    text = text.substring(0, text.length - 1)
  return text
}

function humanizeError(raw, fallback) {
  var s = String(raw || "").toLowerCase()
  var fb = String(fallback || "Playback failed")
  if (!s) return fb
  if (s.indexOf("timed out") !== -1 || s.indexOf("timeout") !== -1)
    return "Timed out talking to YouTube"
  if (
    s.indexOf("network") !== -1
    || s.indexOf("resolve") !== -1
    || s.indexOf("could not connect") !== -1
    || s.indexOf("temporary failure in name") !== -1
    || s.indexOf("connection refused") !== -1
    || s.indexOf("no route") !== -1
    || s.indexOf("http error 5") !== -1
  )
    return "Can't reach YouTube"
  if (s.indexOf("sign in") !== -1 || s.indexOf("not a bot") !== -1)
    return "YouTube asked for a sign-in"
  if (
    s.indexOf("http error 403") !== -1
    || s.indexOf("http error 404") !== -1
    || s.indexOf("video unavailable") !== -1
    || s.indexOf("private video") !== -1
    || s.indexOf("has been removed") !== -1
    || s.indexOf("not available") !== -1
    || s.indexOf("copyright") !== -1
    || s.indexOf("region") !== -1
  )
    return "This session isn't available"
  if (
    s.indexOf("requested format not available") !== -1
    || s.indexOf("no video formats") !== -1
    || s.indexOf("no audio") !== -1
  )
    return "No audio stream for this session"
  if (s.indexOf("catalog") !== -1) return "Couldn't refresh the session list"
  if (s.indexOf("no playable") !== -1) return "No playable tracks"
  return fb
}

function isSkippableError(raw) {
  var s = String(raw || "").toLowerCase()
  if (!s) return true
  if (
    s.indexOf("network") !== -1
    || s.indexOf("timeout") !== -1
    || s.indexOf("timed out") !== -1
    || s.indexOf("resolve") !== -1
    || s.indexOf("could not connect") !== -1
    || s.indexOf("temporary failure in name") !== -1
    || s.indexOf("connection refused") !== -1
    || s.indexOf("no route") !== -1
    || s.indexOf("http error 5") !== -1
    || s.indexOf("catalog") !== -1
  )
    return false
  return true
}

function shouldSurfaceError(failStreak, skippable) {
  var n = Math.max(0, Math.floor(Number(failStreak) || 0))
  if (!skippable) return true
  return n >= 3
}

function parseCtlStatus(raw) {
  var text = String(raw || "").trim()
  if (!text) return null
  try {
    var data = JSON.parse(text)
  } catch (e) {
    return null
  }
  if (!data || typeof data !== "object") return null
  var paused = !!data.pause
  var time = Math.max(0, Math.floor(Number(data.time || 0)))
  var duration = Math.max(0, Math.floor(Number(data.duration || 0)))
  return { pause: paused, time: time, duration: duration }
}

if (typeof module !== "undefined") {
  module.exports = {
    parseCatalog: parseCatalog,
    parseLiveTrack: parseLiveTrack,
    parseLivePayload: parseLivePayload,
    pickTrack: pickTrack,
    pickStartOffset: pickStartOffset,
    rememberId: rememberId,
    snapshotTrack: snapshotTrack,
    pushHistory: pushHistory,
    popHistory: popHistory,
    formatDuration: formatDuration,
    formatProgress: formatProgress,
    barIcon: barIcon,
    stateLabel: stateLabel,
    heroMeta: heroMeta,
    youtubeUrl: youtubeUrl,
    pluginDirFromUrl: pluginDirFromUrl,
    humanizeError: humanizeError,
    isSkippableError: isSkippableError,
    shouldSurfaceError: shouldSurfaceError,
    parseCtlStatus: parseCtlStatus
  }
}
