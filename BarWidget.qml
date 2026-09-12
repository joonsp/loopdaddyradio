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
  readonly property string title: radio ? String(radio.title || "") : ""
  readonly property string videoId: radio ? String(radio.videoId || "") : ""
  readonly property string lastError: radio ? String(radio.lastError || "") : ""
  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

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
    active: root.on
    tooltipText: Model.stateLabel(root.on, root.loading, root.title)
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
          meta: root.loading ? "Tuning in…" : (root.on ? "On air · Marc Rebillet" : "Off")
          detail: root.on && radio && radio.trackCount ? radio.trackCount + " sessions" : ""
          foreground: root.foreground
          fontFamily: root.fontFamily
          iconOpacity: root.on ? 1.0 : 0.55
          iconComponent: Component {
            Text {
              text: "󰐹"
              color: root.on ? root.foreground : root.dim
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
        visible: root.lastError !== ""
        width: parent.width
        text: root.lastError
        color: bar ? bar.urgent : Color.urgent
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
        wrapMode: Text.WordWrap
      }

      Text {
        textFormat: Text.PlainText
        width: parent.width
        text: root.on
          ? (root.title !== "" ? root.title : "Picking a session…")
          : "Toggle on to join a random Loop Daddy session mid-stream. Audio only."
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
        wrapMode: Text.WordWrap
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

      Text {
        textFormat: Text.PlainText
        visible: root.on && radio && radio.duration > 0
        width: parent.width
        text: Model.formatDuration(radio ? radio.duration : 0)
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
      }

      Button {
        width: parent.width
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
  }
}
