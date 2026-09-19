import QtQuick
import qs.Ui
import qs.Commons
import "Model.js" as Model

BarWidget {
  id: root
  moduleName: "joonas.loopdaddyradio"

  property bool popupOpen: false

  readonly property var radio: {
    var sh = bar && bar.shell
    if (!sh) return null
    var _dep = sh._services
    return typeof sh.serviceFor === "function" ? sh.serviceFor("joonas.loopdaddyradio") : null
  }

  readonly property bool on: radio ? radio.on : false
  readonly property bool loading: radio ? radio.loading : false
  readonly property bool paused: radio ? radio.paused : false
  readonly property bool live: radio ? radio.live : false
  readonly property bool needsResume: radio ? radio.needsResume : false
  readonly property bool liveAvailable: radio ? radio.liveAvailable : false
  readonly property string title: radio ? String(radio.title || "") : ""
  readonly property string videoId: radio ? String(radio.videoId || "") : ""
  readonly property string lastError: radio ? String(radio.lastError || "") : ""
  readonly property int elapsed: radio ? Number(radio.elapsed || 0) : 0
  readonly property int duration: radio ? Number(radio.duration || 0) : 0
  readonly property int historyCount: radio ? Number(radio.historyCount || 0) : 0
  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property bool hasError: lastError !== "" && !loading
  readonly property color loadingColor: Qt.tint(Color.accent, Qt.rgba(Color.urgent.r, Color.urgent.g, Color.urgent.b, 0.55))
  readonly property color iconColor: {
    if (hasError) return Color.urgent
    if (loading) return loadingColor
    if (on && !paused) return Color.accent
    if (on || needsResume) return Color.muted
    return dim
  }

  readonly property bool opened: popupOpen

  function open() { popupOpen = true }
  function close() { popupOpen = false }
  function togglePanel() { popupOpen = !popupOpen }

  function toggleRadio() {
    if (radio) radio.toggle()
  }

  function skip() {
    if (radio) radio.skip()
  }

  function back() {
    if (radio) radio.back()
  }

  function togglePause() {
    if (radio) radio.togglePause()
  }

  function playFromStart() {
    if (radio) radio.playFromStart()
  }

  function retry() {
    if (radio) radio.retry()
  }

  function joinLive() {
    if (radio) radio.joinLive()
  }

  function openInYoutube() {
    if (radio) radio.openInYoutube()
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: Model.barIcon(root.on, root.loading)
    active: false
    useActiveColor: false
    foreground: root.iconColor
    tooltipText: Model.stateLabel(root.on, root.loading, root.title, root.lastError, root.paused, root.needsResume, root.live)
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.MiddleButton) root.skip()
      else if (buttonCode === Qt.RightButton) root.togglePanel()
      else root.toggleRadio()
    }
  }

  PopupCard {
    id: popup
    anchorItem: button
    bar: root.bar
    owner: root
    open: root.popupOpen
    contentWidth: popup.fittedContentWidth(Style.space(340))
    contentHeight: popup.fittedContentHeight(column.implicitHeight)

    Column {
      id: column
      anchors.fill: parent
      spacing: Style.space(12)

      Item {
        id: header
        width: parent.width
        implicitHeight: hero.implicitHeight
        readonly property bool radioOn: root.on
        function toggleRadio() { root.toggleRadio() }

        PanelHero {
          id: hero
          width: parent.width
          title: "Loop Daddy Radio"
          meta: Model.heroMeta(root.on, root.loading, root.lastError, root.paused, root.needsResume, root.live)
          detail: root.on && radio && radio.trackCount ? radio.trackCount + " sessions" : ""
          foreground: root.foreground
          fontFamily: root.fontFamily
          iconOpacity: root.on || root.needsResume ? 1.0 : 0.55
          iconComponent: Component {
            Text {
              text: "󰐹"
              color: root.iconColor
              font.family: root.fontFamily
              font.pixelSize: Style.font.display
            }
          }
          trailingControl: Component {
            ToggleSwitch {
              checked: header.radioOn
              foreground: hero.foreground
              onToggled: header.toggleRadio()
            }
          }
        }
      }

      Text {
        textFormat: Text.PlainText
        visible: root.hasError
        width: parent.width
        text: root.lastError
        color: Color.urgent
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
        wrapMode: Text.WordWrap
      }

      Text {
        textFormat: Text.PlainText
        width: parent.width
        text: root.needsResume
          ? "Was on last session. Click the radio to resume."
          : (root.on
            ? (root.title !== "" ? root.title : "Picking a session…")
            : "Toggle on to join a random Loop Daddy session mid-stream. Audio only.")
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
        wrapMode: Text.WordWrap
      }

      Text {
        textFormat: Text.PlainText
        visible: root.on && Model.formatProgress(root.elapsed, root.duration, root.live) !== ""
        width: parent.width
        text: Model.formatProgress(root.elapsed, root.duration, root.live)
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
      }

      Button {
        visible: root.on && root.videoId !== ""
        text: "Open in YouTube"
        tooltipText: "Open this session in the browser"
        foreground: root.dim
        fontFamily: root.fontFamily
        fontSize: Style.font.caption
        bordered: false
        leftAlign: true
        horizontalPadding: Style.space(8)
        verticalPadding: Style.space(6)
        onClicked: root.openInYoutube()
      }

      Row {
        visible: root.on
        width: parent.width
        spacing: Style.space(8)

        Button {
          width: (parent.width - parent.spacing) / 2
          text: root.paused ? "Resume" : "Pause"
          tooltipText: root.paused ? "Continue this session" : "Pause without turning the station off"
          foreground: root.foreground
          fontFamily: root.fontFamily
          bordered: true
          enabled: root.on && !root.loading
          opacity: enabled ? 1 : 0.45
          horizontalPadding: Style.space(16)
          verticalPadding: Style.space(14)
          onClicked: root.togglePause()
        }

        Button {
          width: (parent.width - parent.spacing) / 2
          text: "Skip"
          tooltipText: "Play another random session"
          foreground: root.foreground
          fontFamily: root.fontFamily
          bordered: true
          enabled: root.on
          opacity: enabled ? 1 : 0.45
          horizontalPadding: Style.space(16)
          verticalPadding: Style.space(14)
          onClicked: root.skip()
        }
      }

      Row {
        visible: root.on
        width: parent.width
        spacing: Style.space(8)

        Button {
          width: (parent.width - parent.spacing) / 2
          text: "Back"
          tooltipText: "Return to the previous session"
          foreground: root.foreground
          fontFamily: root.fontFamily
          bordered: true
          enabled: root.historyCount > 0
          opacity: enabled ? 1 : 0.45
          horizontalPadding: Style.space(16)
          verticalPadding: Style.space(14)
          onClicked: root.back()
        }

        Button {
          width: (parent.width - parent.spacing) / 2
          text: "From the start"
          tooltipText: "Play this session from the beginning"
          foreground: root.foreground
          fontFamily: root.fontFamily
          bordered: true
          enabled: root.on && root.videoId !== "" && !root.live
          opacity: enabled ? 1 : 0.45
          horizontalPadding: Style.space(16)
          verticalPadding: Style.space(14)
          onClicked: root.playFromStart()
        }
      }

      Button {
        visible: root.liveAvailable
        width: parent.width
        text: "Join live"
        tooltipText: "Switch to the live Loop Daddy session"
        foreground: root.foreground
        fontFamily: root.fontFamily
        bordered: true
        horizontalPadding: Style.space(16)
        verticalPadding: Style.space(14)
        onClicked: root.joinLive()
      }

      Button {
        visible: root.hasError
        width: parent.width
        text: "Retry"
        tooltipText: "Try again"
        foreground: root.foreground
        fontFamily: root.fontFamily
        bordered: true
        horizontalPadding: Style.space(16)
        verticalPadding: Style.space(14)
        onClicked: root.retry()
      }
    }
  }
}
