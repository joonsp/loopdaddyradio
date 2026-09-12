import QtQuick
import Quickshell
import Quickshell.Io
import "Model.js" as Model

Item {
  id: root

  property var shell: null
  property var manifest: null

  readonly property string pluginDir: Model.pluginDirFromUrl(Qt.resolvedUrl("."))
  readonly property string cli: pluginDir + "/bin/loopdaddyradio"

  property bool on: false
  property bool loading: false
  property bool catalogReady: false
  property bool stopping: false
  property bool persistReady: false
  property string lastError: ""
  property var tracks: []
  property var recentIds: []
  property var currentTrack: null
  property int fetchedAt: 0
  property bool randomStart: false
  property string playErrTail: ""
  property string catalogErrTail: ""

  readonly property string title: currentTrack ? String(currentTrack.title || "") : ""
  readonly property string videoId: currentTrack ? String(currentTrack.id || "") : ""
  readonly property int duration: currentTrack ? Number(currentTrack.duration || 0) : 0
  readonly property bool playing: on && playProc.running && !loading
  readonly property int trackCount: tracks.length

  function applyCatalog(raw) {
    var parsed = Model.parseCatalog(raw)
    if (!parsed.ok) {
      lastError = parsed.lastError || "Catalog failed"
      catalogReady = tracks.length > 0
      return false
    }
    tracks = parsed.tracks
    fetchedAt = parsed.fetchedAt
    catalogReady = tracks.length > 0
    if (catalogReady) lastError = ""
    return catalogReady
  }

  function clipTail(prev, chunk, maxBytes) {
    var s = String(prev || "") + String(chunk || "")
    var cap = Math.max(64, Number(maxBytes) || 400)
    if (s.length > cap) s = s.substring(s.length - cap)
    return s
  }

  function persistEnabled() {
    if (persistProc.running) return
    persistProc.command = [cli, "enabled", root.on ? "on" : "off"]
    persistProc.running = true
  }

  function loadCatalog(force) {
    if (catalogProc.running) return
    catalogErrTail = ""
    catalogProc.command = force ? [cli, "catalog", "--refresh"] : [cli, "catalog"]
    catalogProc.running = true
    catalogTermTimer.restart()
  }

  function stopCatalog() {
    catalogTermTimer.stop()
    if (!catalogProc.running) {
      catalogKillTimer.stop()
      return
    }
    catalogProc.signal(15)
    catalogKillTimer.restart()
  }

  function stopPlay() {
    if (!playProc.running) {
      playKillTimer.stop()
      return
    }
    playProc.signal(15)
    playKillTimer.restart()
  }

  function playTrack(track, startSeconds) {
    if (!track || !track.id) return
    currentTrack = track
    recentIds = Model.rememberId(recentIds, track.id, 24)
    lastError = ""
    playErrTail = ""
    loading = true
    var start = Math.max(0, Math.floor(Number(startSeconds) || 0))
    var cmd = [cli, "play", String(track.id), String(track.title || "Loop Daddy Radio")]
    if (start > 0) cmd.push(String(start))
    playProc.command = cmd
    playProc.running = true
    startedTimer.restart()
  }

  function playNext() {
    if (!root.on) return
    if (!catalogReady) {
      loading = true
      loadCatalog(false)
      return
    }
    if (playProc.running) {
      stopPlay()
      return
    }
    var track = Model.pickTrack(tracks, recentIds)
    if (!track) {
      lastError = "No playable tracks"
      loading = false
      return
    }
    var start = 0
    if (root.randomStart) {
      start = Model.pickStartOffset(track.duration)
      root.randomStart = false
    }
    playTrack(track, start)
  }

  function setOn(value) {
    var next = !!value
    if (root.on === next && persistReady) {
      if (next && !playProc.running) {
        root.randomStart = true
        playNext()
      }
      return
    }
    root.on = next
    persistEnabled()
    if (!next) {
      loading = false
      startedTimer.stop()
      currentTrack = null
      root.randomStart = false
      stopping = playProc.running
      stopPlay()
      return
    }
    root.randomStart = true
    playNext()
  }

  function toggle() {
    setOn(!root.on)
  }

  function skip() {
    if (!root.on) return
    root.randomStart = true
    playNext()
  }

  function openInYoutube() {
    var url = Model.youtubeUrl(root.videoId)
    if (!url) return false
    Qt.openUrlExternally(url)
    return true
  }

  function statusJson() {
    return JSON.stringify({
      on: root.on,
      loading: root.loading,
      playing: root.playing,
      title: root.title,
      duration: root.duration,
      trackCount: root.trackCount,
      lastError: root.lastError,
      videoId: root.videoId
    })
  }

  Process {
    id: enabledProc
    command: [root.cli, "enabled"]
    running: true
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.persistReady = true
        var value = String(text || "").trim()
        if (value.length > 8) value = value.substring(0, 8)
        if (value === "on") root.setOn(true)
      }
    }
    onExited: function() { root.persistReady = true }
  }

  Process {
    id: persistProc
    running: false
    command: []
  }

  Process {
    id: catalogProc
    running: false
    command: []
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var raw = String(text || "")
        if (raw.length > 524288) {
          root.lastError = "Catalog too large"
          root.loading = false
          return
        }
        var ok = root.applyCatalog(raw)
        if (root.on && ok && !playProc.running) root.playNext()
      }
    }
    stderr: SplitParser {
      onRead: function(data) {
        root.catalogErrTail = root.clipTail(root.catalogErrTail, data, 400)
      }
    }
    onStarted: catalogTermTimer.restart()
    onExited: function(exitCode) {
      catalogTermTimer.stop()
      catalogKillTimer.stop()
      if (exitCode !== 0 && !root.catalogReady) {
        var err = String(root.catalogErrTail || "").trim()
        root.lastError = err || "Catalog failed"
        root.loading = false
      }
    }
  }

  Process {
    id: playProc
    running: false
    command: []
    stderr: SplitParser {
      onRead: function(data) {
        root.playErrTail = root.clipTail(root.playErrTail, data, 400)
      }
    }
    onExited: function(exitCode) {
      root.loading = false
      startedTimer.stop()
      playKillTimer.stop()
      if (root.stopping) {
        root.stopping = false
        root.currentTrack = null
        return
      }
      if (!root.on) {
        root.currentTrack = null
        return
      }
      if (exitCode !== 0) {
        var err = String(root.playErrTail || "").trim()
        if (err) root.lastError = err
      }
      retryTimer.restart()
    }
  }

  Timer {
    id: startedTimer
    interval: 1500
    repeat: false
    onTriggered: if (playProc.running) root.loading = false
  }

  Timer {
    id: retryTimer
    interval: 400
    repeat: false
    onTriggered: if (root.on) root.playNext()
  }

  Timer {
    id: catalogRefresh
    interval: 24 * 60 * 60 * 1000
    repeat: true
    running: true
    onTriggered: root.loadCatalog(true)
  }

  Timer {
    id: catalogTermTimer
    interval: 180000
    repeat: false
    onTriggered: root.stopCatalog()
  }

  Timer {
    id: catalogKillTimer
    interval: 5000
    repeat: false
    onTriggered: if (catalogProc.running) catalogProc.signal(9)
  }

  Timer {
    id: playKillTimer
    interval: 1000
    repeat: false
    onTriggered: if (playProc.running) playProc.signal(9)
  }

  Component.onCompleted: loadCatalog(false)

  IpcHandler {
    target: "joonas.loopdaddyradio"

    function status(): string {
      return root.statusJson()
    }

    function toggle(): string {
      root.toggle()
      return root.on ? "on" : "off"
    }

    function enable(): string {
      root.setOn(true)
      return "on"
    }

    function disable(): string {
      root.setOn(false)
      return "off"
    }

    function skip(): string {
      root.skip()
      return root.currentTrack ? String(root.currentTrack.title || "") : "ok"
    }

    function open(): string {
      return root.openInYoutube() ? "ok" : "off"
    }

    function ping(): string {
      return "ok"
    }
  }
}
