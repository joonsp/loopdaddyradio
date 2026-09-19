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
  property bool replacing: false
  property bool persistReady: false
  property bool paused: false
  property bool needsResume: false
  property string lastError: ""
  property var tracks: []
  property var recentIds: []
  property var playHistory: []
  property var currentTrack: null
  property var liveTrack: null
  property var pendingPlay: null
  property int fetchedAt: 0
  property int lastStart: 0
  property int elapsed: 0
  property int failStreak: 0
  property bool randomStart: false
  property string playErrTail: ""
  property string catalogErrTail: ""

  readonly property string title: currentTrack ? String(currentTrack.title || "") : ""
  readonly property string videoId: currentTrack ? String(currentTrack.id || "") : ""
  readonly property int duration: {
    var fromTrack = currentTrack ? Number(currentTrack.duration || 0) : 0
    return fromTrack > 0 ? fromTrack : 0
  }
  readonly property bool live: !!(currentTrack && currentTrack.live)
  readonly property bool playing: on && playProc.running && !loading && !paused
  readonly property int trackCount: tracks.length
  readonly property int historyCount: playHistory.length
  readonly property bool liveAvailable: !!(liveTrack && liveTrack.id && String(liveTrack.id) !== root.videoId)

  function applyCatalog(raw) {
    var parsed = Model.parseCatalog(raw)
    if (!parsed.ok) {
      lastError = Model.humanizeError(parsed.lastError, "Couldn't refresh the session list")
      catalogReady = tracks.length > 0
      return false
    }
    tracks = parsed.tracks
    fetchedAt = parsed.fetchedAt
    if (parsed.live) liveTrack = parsed.live
    catalogReady = tracks.length > 0
    if (catalogReady && !root.lastError) lastError = ""
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

  function loadLive() {
    if (liveProc.running) return
    liveProc.command = [cli, "live"]
    liveProc.running = true
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
    statusPoll.stop()
    if (!playProc.running) {
      playKillTimer.stop()
      return
    }
    playProc.signal(15)
    playKillTimer.restart()
  }

  function queryStatus() {
    if (!playProc.running || ctlStatusProc.running || ctlCmdProc.running) return
    ctlStatusProc.command = [cli, "ctl", "status"]
    ctlStatusProc.running = true
  }

  function applyCtlStatus(raw) {
    var st = Model.parseCtlStatus(raw)
    if (!st) return
    root.paused = st.pause
    root.elapsed = st.time
  }

  function playTrack(track, startSeconds) {
    if (!track || !track.id) return
    if (playProc.running) {
      pendingPlay = { track: track, start: startSeconds }
      replacing = true
      stopPlay()
      return
    }
    if (currentTrack && currentTrack.id && String(currentTrack.id) !== String(track.id))
      playHistory = Model.pushHistory(playHistory, currentTrack, root.elapsed || lastStart)
    currentTrack = track
    recentIds = Model.rememberId(recentIds, track.id, 24)
    lastError = ""
    playErrTail = ""
    paused = false
    loading = true
    failStreak = 0
    var start = Math.max(0, Math.floor(Number(startSeconds) || 0))
    lastStart = start
    elapsed = start
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
      replacing = true
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

  function handlePlayExit(exitCode) {
    if (pendingPlay) {
      var queued = pendingPlay
      pendingPlay = null
      replacing = false
      playTrack(queued.track, queued.start)
      return
    }
    if (root.replacing) {
      replacing = false
      if (root.on) retryTimer.restart()
      return
    }
    if (root.stopping) {
      root.stopping = false
      root.currentTrack = null
      root.paused = false
      root.elapsed = 0
      return
    }
    if (!root.on) {
      root.currentTrack = null
      root.paused = false
      return
    }
    if (exitCode !== 0) {
      var raw = String(root.playErrTail || "").trim()
      var skippable = Model.isSkippableError(raw)
      failStreak += 1
      if (Model.shouldSurfaceError(failStreak, skippable)) {
        lastError = Model.humanizeError(raw, "Playback failed")
        loading = false
        if (!skippable) return
      }
    } else {
      failStreak = 0
    }
    retryTimer.restart()
  }

  function setOn(value) {
    var next = !!value
    if (root.on === next && persistReady) {
      if (next && !playProc.running) {
        root.needsResume = false
        root.randomStart = true
        playNext()
      }
      return
    }
    root.on = next
    root.needsResume = false
    persistEnabled()
    if (!next) {
      loading = false
      startedTimer.stop()
      statusPoll.stop()
      pendingPlay = null
      replacing = false
      currentTrack = null
      paused = false
      elapsed = 0
      lastError = ""
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
    failStreak = 0
    lastError = ""
    playNext()
  }

  function back() {
    var popped = Model.popHistory(playHistory)
    playHistory = popped.history
    if (!popped.track) return
    if (!root.on) {
      root.on = true
      persistEnabled()
    }
    root.randomStart = false
    failStreak = 0
    lastError = ""
    playTrack(popped.track, popped.track.start || 0)
  }

  function playFromStart() {
    if (!root.on || !currentTrack) return
    root.randomStart = false
    playTrack(currentTrack, 0)
  }

  function retry() {
    lastError = ""
    failStreak = 0
    if (!root.on) {
      setOn(true)
      return
    }
    if (currentTrack) {
      playTrack(currentTrack, lastStart)
      return
    }
    root.randomStart = true
    playNext()
  }

  function joinLive() {
    if (!liveTrack || !liveTrack.id) {
      loadLive()
      return false
    }
    if (!root.on) {
      root.on = true
      persistEnabled()
    }
    root.needsResume = false
    root.randomStart = false
    failStreak = 0
    lastError = ""
    playTrack(liveTrack, 0)
    return true
  }

  function setPaused(value) {
    if (!playProc.running || ctlCmdProc.running) return
    ctlCmdProc.command = [cli, "ctl", value ? "pause" : "unpause"]
    ctlCmdProc.running = true
  }

  function togglePause() {
    if (!root.on || loading) return
    setPaused(!root.paused)
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
      paused: root.paused,
      live: root.live,
      needsResume: root.needsResume,
      title: root.title,
      duration: root.duration,
      elapsed: root.elapsed,
      trackCount: root.trackCount,
      lastError: root.lastError,
      videoId: root.videoId
    })
  }

  Process {
    id: restoreProc
    command: [root.cli, "restore"]
    running: true
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.persistReady = true
        var value = String(text || "").trim()
        if (value === "play") root.setOn(true)
        else if (value === "resume") root.needsResume = true
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
          root.lastError = "Couldn't refresh the session list"
          root.loading = false
          return
        }
        var ok = root.applyCatalog(raw)
        root.loadLive()
        if (root.on && ok && !playProc.running && !root.pendingPlay) root.playNext()
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
        root.lastError = Model.humanizeError(err, "Couldn't refresh the session list")
        root.loading = false
      }
    }
  }

  Process {
    id: liveProc
    running: false
    command: []
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var parsed = Model.parseLivePayload(text)
        if (parsed) root.liveTrack = parsed
        else if (String(text || "").indexOf('"live":false') !== -1) root.liveTrack = null
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
      statusPoll.stop()
      root.handlePlayExit(exitCode)
    }
  }

  Process {
    id: ctlStatusProc
    running: false
    command: []
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.applyCtlStatus(text)
    }
  }

  Process {
    id: ctlCmdProc
    running: false
    command: []
    onExited: function() { root.queryStatus() }
  }

  Timer {
    id: startedTimer
    interval: 1500
    repeat: false
    onTriggered: {
      if (playProc.running) {
        root.loading = false
        statusPoll.restart()
        root.queryStatus()
      }
    }
  }

  Timer {
    id: retryTimer
    interval: 400
    repeat: false
    onTriggered: if (root.on) root.playNext()
  }

  Timer {
    id: statusPoll
    interval: 1000
    repeat: true
    onTriggered: root.queryStatus()
  }

  Timer {
    id: catalogRefresh
    interval: 24 * 60 * 60 * 1000
    repeat: true
    running: true
    onTriggered: root.loadCatalog(true)
  }

  Timer {
    id: liveRefresh
    interval: 15 * 60 * 1000
    repeat: true
    running: true
    onTriggered: root.loadLive()
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

  Component.onCompleted: {
    loadCatalog(false)
    loadLive()
  }

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

    function back(): string {
      root.back()
      return root.currentTrack ? String(root.currentTrack.title || "") : "ok"
    }

    function pause(): string {
      root.setPaused(true)
      return "ok"
    }

    function unpause(): string {
      root.setPaused(false)
      return "ok"
    }

    function playPause(): string {
      root.togglePause()
      return root.paused ? "paused" : "playing"
    }

    function replay(): string {
      root.playFromStart()
      return "ok"
    }

    function retry(): string {
      root.retry()
      return "ok"
    }

    function live(): string {
      return root.joinLive() ? "ok" : "off"
    }

    function open(): string {
      return root.openInYoutube() ? "ok" : "off"
    }

    function ping(): string {
      return "ok"
    }
  }
}
