function parseCatalog(raw) {
  try {
    var data = JSON.parse(String(raw || "").trim())
  } catch (e) {
    return { ok: false, lastError: "Could not parse catalog" }
  }
  if (!data || typeof data !== "object" || !Array.isArray(data.tracks))
    return { ok: false, lastError: "Catalog is empty" }
  var tracks = []
  for (var i = 0; i < data.tracks.length; i++) {
    var track = data.tracks[i]
    if (!track || !track.id) continue
    tracks.push({
      id: String(track.id),
      title: String(track.title || "Untitled"),
      duration: Number(track.duration || 0)
    })
  }
  if (tracks.length === 0) return { ok: false, lastError: "No playable tracks" }
  return {
    ok: true,
    channel: String(data.channel || ""),
    fetchedAt: Number(data.fetchedAt || 0),
    tracks: tracks
  }
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

function formatDuration(seconds) {
  var s = Math.max(0, Math.round(Number(seconds) || 0))
  if (s <= 0) return ""
  var h = Math.floor(s / 3600)
  var m = Math.floor((s % 3600) / 60)
  if (h > 0) return h + "h " + m + "m"
  if (m > 0) return m + " min"
  return s + "s"
}

function barIcon(on, loading) {
  if (loading) return "󰔟"
  if (on) return "󰐹"
  return "󰐹"
}

function stateLabel(on, loading, title) {
  if (loading) return "Tuning in…"
  if (on && title) return title
  if (on) return "On air"
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

if (typeof module !== "undefined") {
  module.exports = {
    parseCatalog: parseCatalog,
    pickTrack: pickTrack,
    pickStartOffset: pickStartOffset,
    rememberId: rememberId,
    formatDuration: formatDuration,
    barIcon: barIcon,
    stateLabel: stateLabel,
    youtubeUrl: youtubeUrl,
    pluginDirFromUrl: pluginDirFromUrl
  }
}
