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

  function persistEnabled() {
    if (persistProc.running) return
    persistProc.command = [cli, "enabled", root.on ? "on" : "off"]
    persistProc.running = true
  }

  function loadCatalog(force) {
    if (catalogProc.running) return
    catalogProc.command = force ? [cli, "catalog", "--refresh"] : [cli, "catalog"]
    catalogProc.running = true
  }

  function playTrack(track, startSeconds) {
    if (!track || !track.id) return
    currentTrack = track
    recentIds = Model.rememberId(recentIds, track.id, 24)
    lastError = ""
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
      playProc.running = false
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
      if (playProc.running) playProc.running = false
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
        var ok = root.applyCatalog(text)
        if (root.on && ok && !playProc.running) root.playNext()
      }
    }
    stderr: StdioCollector {
      id: catalogErr
      waitForEnd: true
    }
    onExited: function(exitCode) {
      if (exitCode !== 0 && !root.catalogReady) {
        root.lastError = String(catalogErr.text || "Catalog failed").trim()
        root.loading = false
      }
    }
  }

  Process {
    id: playProc
    running: false
    command: []
    stderr: StdioCollector {
      id: playErr
      waitForEnd: true
    }
    onExited: function(exitCode) {
      root.loading = false
      startedTimer.stop()
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
        var err = String(playErr.text || "").trim()
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
