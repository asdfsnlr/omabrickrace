import QtQuick
import QtMultimedia
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "GameModel.js" as Game

Panel {
  id: root
  moduleName: "omabrickrace"
  ipcTarget: "omabrickrace"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root
  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  // Settings properties with initial fallback to shell.json injected settings
  property bool soundEnabled: settings && settings.soundEnabled !== undefined ? settings.soundEnabled === true : true
  property bool classicLcdColors: settings && settings.classicLcdColors !== undefined ? settings.classicLcdColors === true : true

  property var game: Game.create()
  property int sessionBest: 0
  readonly property int storedBest: Math.max(0, Number(setting("bestScore", 0)) || 0)
  readonly property int bestScore: Math.max(storedBest, sessionBest)

  readonly property color lcdScreenBg: root.classicLcdColors ? "#92a477" : Color.popups.background
  readonly property color lcdScreenBorder: root.classicLcdColors ? "#77875f" : Color.popups.border
  readonly property color lcdLitPixel: root.classicLcdColors ? "#162010" : Color.accent
  readonly property color lcdGhostPixel: root.classicLcdColors ? "#84956a" : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.05)
  readonly property color lcdTextDark: root.classicLcdColors ? "#162010" : root.foreground
  readonly property color lcdTextMuted: root.classicLcdColors ? "#586944" : Color.muted

  // Persistence directory: ~/.local/state/omabrickrace/settings.json
  readonly property string stateHome: {
    var xdg = Quickshell.env("XDG_STATE_HOME")
    return xdg && xdg.length > 0 ? xdg : Quickshell.env("HOME") + "/.local/state"
  }
  readonly property string stateDir: stateHome + "/omabrickrace"

  Process {
    command: ["mkdir", "-p", root.stateDir]
    running: true
  }

  FileView {
    id: settingsFile
    path: root.stateDir + "/settings.json"
    printErrors: false
    watchChanges: false
    onLoaded: {
      try {
        var val = JSON.parse(text())
        if (val) {
          if (val.classicLcdColors !== undefined) root.classicLcdColors = val.classicLcdColors === true
          if (val.soundEnabled !== undefined) root.soundEnabled = val.soundEnabled === true
          if (val.bestScore !== undefined) {
            var scoreVal = Math.max(0, Math.floor(Number(val.bestScore) || 0))
            if (scoreVal > root.sessionBest) root.sessionBest = scoreVal
          }
        }
      } catch (e) {
        // Invalid or empty settings file fallback
      }
    }
  }

  function saveSettings() {
    var data = {
      version: 1,
      soundEnabled: root.soundEnabled,
      classicLcdColors: root.classicLcdColors,
      bestScore: root.bestScore
    }
    settingsFile.setText(JSON.stringify(data, null, 2) + "\n")

    // Also persist inline to shell.json
    var entry = {
      id: root.moduleName,
      soundEnabled: root.soundEnabled,
      classicLcdColors: root.classicLcdColors,
      bestScore: root.bestScore
    }
    root.settings = entry
    if (root.hostWidget && "settings" in root.hostWidget) root.hostWidget.settings = entry
    if (root.bar && root.bar.shell && typeof root.bar.shell.updateEntryInline === "function") {
      root.bar.shell.updateEntryInline(root.moduleName, entry)
    }
  }

  function open() {
    root.controller.show()
  }

  function close() {
    root.setTurbo(false)
    root.game = Game.pause(root.game)
    root.controller.hide()
  }

  function toggle() {
    if (root.opened) root.close()
    else root.open()
  }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.barIdentity, direction)
    return false
  }

  function restart() {
    root.setTurbo(false)
    var next = Game.restart(root.game)
    root.handleEvents(next.events)
    root.game = next
  }

  function startOrRestart() {
    root.restart()
  }

  function togglePause() {
    if (root.game.status === Game.STATUS_GAME_OVER) {
      root.startOrRestart()
      return
    }
    var next = Game.togglePause(root.game)
    root.handleEvents(next.events)
    root.game = next
  }

  function steer(lane) {
    if (root.game.status === Game.STATUS_READY) {
      root.startOrRestart()
    }
    root.game = Game.steer(root.game, lane)
  }

  function setTurbo(active) {
    if (root.game.status === Game.STATUS_READY && active) {
      root.startOrRestart()
    }
    root.game = Game.setTurbo(root.game, active)
  }

  function persistBest(score) {
    var value = Math.max(0, Math.floor(Number(score) || 0))
    if (value <= root.bestScore) return
    root.sessionBest = value
    root.saveSettings()
  }

  function toggleSound() {
    root.soundEnabled = !root.soundEnabled
    root.saveSettings()
  }

  function toggleLcdTheme() {
    root.classicLcdColors = !root.classicLcdColors
    root.saveSettings()
  }

  function handleEvents(events) {
    if (!root.soundEnabled || !events) return
    for (var i = 0; i < events.length; i++) {
      var ev = events[i]
      if (ev === "steer") soundSteer.play()
      else if (ev === "score") soundScore.play()
      else if (ev === "crash") soundCrash.play()
      else if (ev === "start") soundStart.play()
      else if (ev === "gameover") soundGameOver.play()
    }
  }

  onGameChanged: persistBest(game.score)

  SoundEffect { id: soundSteer; source: Qt.resolvedUrl("sounds/steer.wav"); volume: 0.25; muted: !root.soundEnabled }
  SoundEffect { id: soundScore; source: Qt.resolvedUrl("sounds/score.wav"); volume: 0.35; muted: !root.soundEnabled }
  SoundEffect { id: soundCrash; source: Qt.resolvedUrl("sounds/crash.wav"); volume: 0.45; muted: !root.soundEnabled }
  SoundEffect { id: soundStart; source: Qt.resolvedUrl("sounds/start.wav"); volume: 0.35; muted: !root.soundEnabled }
  SoundEffect { id: soundGameOver; source: Qt.resolvedUrl("sounds/gameover.wav"); volume: 0.4; muted: !root.soundEnabled }

  Timer {
    id: gameTimer
    interval: root.game.tickMs
    running: root.opened && (root.game.status === Game.STATUS_PLAYING || root.game.status === Game.STATUS_CRASH)
    repeat: true
    onTriggered: {
      var next = Game.step(root.game, Math.random)
      root.handleEvents(next.events)
      root.game = next
    }
  }

  // Fallback watchdog timer for keyboard repeat release detection
  Timer {
    id: boostWatchdogTimer
    interval: 450
    repeat: false
    onTriggered: root.setTurbo(false)
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    centerOnBar: true
    gap: Math.max(Style.gapsOut, Math.round((panel.screenH - panel.barH - panel.contentHeight) / 2))
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(400))
    contentHeight: panel.fittedContentHeight(contentColumn.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent

      onMoveRequested: function(dx, dy) {
        if (dx < 0) root.steer(Game.LANE_LEFT)
        else if (dx > 0) root.steer(Game.LANE_RIGHT)

        if (dy < 0) {
          root.setTurbo(true)
          boostWatchdogTimer.restart()
        }
      }

      onActivateRequested: {
        if (root.game.status === Game.STATUS_READY || root.game.status === Game.STATUS_GAME_OVER) {
          root.startOrRestart()
        } else {
          root.togglePause()
        }
      }

      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      onTextKey: function(text) {
        var k = text.toLowerCase()
        if (k === "a" || k === "h") root.steer(Game.LANE_LEFT)
        else if (k === "d" || k === "l") root.steer(Game.LANE_RIGHT)
        else if (k === "w" || k === "k") {
          root.setTurbo(true)
          boostWatchdogTimer.restart()
        }
        else if (k === "p") root.togglePause()
        else if (k === "r") root.startOrRestart()
        else if (k === "m") root.toggleSound()
        else if (k === "c") root.toggleLcdTheme()
      }

      Keys.onReleased: function(event) {
        // Ignore synthetic autorepeat releases from X11/Wayland keyboard drivers
        if (event.isAutoRepeat) {
          event.accepted = true
          return
        }
        if (event.key === Qt.Key_Up || event.key === Qt.Key_W || event.text === "w" || event.text === "k") {
          boostWatchdogTimer.stop()
          root.setTurbo(false)
          event.accepted = true
        }
      }

      Column {
        id: contentColumn
        width: parent.width
        spacing: Style.space(12)

        // Header with pixel car icon, OmaBrickRace title, and action buttons
        Item {
          width: parent.width
          height: Style.space(34)

          Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(10)

            // Matching pixel car glyph from the status bar widget
            Grid {
              anchors.verticalCenter: parent.verticalCenter
              columns: 3
              rows: 4
              spacing: 1

              Repeater {
                model: [
                  0, 1, 0,
                  1, 1, 1,
                  0, 1, 0,
                  1, 1, 1
                ]
                Rectangle {
                  required property int modelData
                  width: Style.space(4)
                  height: Style.space(4)
                  radius: 0.5
                  color: modelData === 1 ? Color.accent : "transparent"
                }
              }
            }

            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: "OmaBrickRace"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodyLarge
              font.bold: true
            }
          }

          Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(4)

            Button {
              width: Style.space(30)
              height: Style.space(30)
              iconText: root.soundEnabled ? "󰕾" : "󰝟"
              iconSize: Style.font.icon
              tooltipText: root.soundEnabled ? "Mute sound [M]" : "Unmute sound [M]"
              foreground: root.soundEnabled ? root.foreground : Color.muted
              onClicked: root.toggleSound()
            }

            Button {
              width: Style.space(30)
              height: Style.space(30)
              iconText: "󰏘"
              iconSize: Style.font.icon
              tooltipText: root.classicLcdColors ? "Theme Colors [C]" : "Classic LCD [C]"
              foreground: root.classicLcdColors ? Color.accent : root.foreground
              onClicked: root.toggleLcdTheme()
            }

            Button {
              width: Style.space(30)
              height: Style.space(30)
              iconText: root.game.status === Game.STATUS_PLAYING ? "󰏤" : "󰐊"
              iconSize: Style.font.icon
              tooltipText: root.game.status === Game.STATUS_PLAYING ? "Pause [P]" : "Play [Space]"
              foreground: root.foreground
              onClicked: root.togglePause()
            }

            Button {
              width: Style.space(30)
              height: Style.space(30)
              iconText: "󰑐"
              iconSize: Style.font.icon
              tooltipText: "Restart [R]"
              foreground: root.foreground
              onClicked: root.startOrRestart()
            }
          }
        }

        // Main LCD Console Screen (Track Matrix + Side HUD)
        BorderSurface {
          id: lcdBezel
          width: parent.width
          height: Style.space(358)
          color: root.classicLcdColors ? "#8b9c71" : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.035)
          borderSpec: Border.surfaceSpec("popups", "border", root.lcdScreenBorder, Math.max(1, Style.normalBorderWidth))
          radius: Style.cornerRadius

          Row {
            anchors.centerIn: parent
            spacing: Style.space(16)

            // 10x20 LCD Track Screen (Scaled up for comfortable gameplay)
            Rectangle {
              id: screenArea
              width: Style.space(170)
              height: Style.space(340)
              color: root.lcdScreenBg
              border.width: 1
              border.color: root.lcdScreenBorder
              radius: Style.space(4)
              clip: true

              readonly property int cellWidth: Math.floor(width / Game.COLS)
              readonly property int cellHeight: Math.floor(height / Game.ROWS)

              Grid {
                anchors.centerIn: parent
                columns: Game.COLS
                rows: Game.ROWS

                Repeater {
                  model: Game.COLS * Game.ROWS

                  Item {
                    required property int index
                    width: screenArea.cellWidth
                    height: screenArea.cellHeight
                    readonly property bool lit: Game.cellLit(root.game, index)

                    // Ghost / unlit pixel in background
                    Rectangle {
                      anchors.fill: parent
                      anchors.margins: 1
                      color: root.lcdGhostPixel
                      radius: Style.cornerRadius > 0 ? 0.5 : 0
                    }

                    // Lit active pixel
                    Rectangle {
                      anchors.fill: parent
                      anchors.margins: 1
                      visible: parent.lit
                      color: root.lcdLitPixel
                      radius: Style.cornerRadius > 0 ? 0.5 : 0

                      // Subtle inner bevel for liquid crystal effect
                      Rectangle {
                        anchors.fill: parent
                        anchors.margins: 1
                        color: "transparent"
                        border.width: 1
                        border.color: root.classicLcdColors ? "#273619" : Qt.rgba(1, 1, 1, 0.2)
                        radius: Style.cornerRadius > 0 ? 0.5 : 0
                      }
                    }
                  }
                }
              }

              // Ready / Paused / Game Over Centered Overlay
              Rectangle {
                anchors.centerIn: parent
                visible: root.game.status !== Game.STATUS_PLAYING && root.game.status !== Game.STATUS_CRASH
                width: overlayText.implicitWidth + Style.space(24)
                height: overlayText.implicitHeight + Style.space(16)
                radius: Style.space(4)
                color: root.classicLcdColors ? "#92a477" : Color.popups.background
                border.width: 1
                border.color: root.classicLcdColors ? "#162010" : Color.popups.border

                Text {
                  id: overlayText
                  anchors.centerIn: parent
                  text: {
                    if (root.game.status === Game.STATUS_READY) return "READY\nPRESS START"
                    if (root.game.status === Game.STATUS_PAUSED) return "PAUSED"
                    if (root.game.status === Game.STATUS_GAME_OVER) return "GAME OVER"
                    return ""
                  }
                  horizontalAlignment: Text.AlignHCenter
                  color: root.game.status === Game.STATUS_GAME_OVER ? (root.classicLcdColors ? "#162010" : Color.urgent) : root.lcdTextDark
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.bodySmall
                  font.bold: true
                }
              }

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  keyCatcher.forceActiveFocus()
                  root.togglePause()
                }
              }
            }

            // Side HUD (Score, Hi-Score, Speed, Cars, Segmented Boost Gauge)
            Column {
              width: Style.space(146)
              height: Style.space(340)
              spacing: Style.space(10)

              // SCORE Box
              Column {
                width: parent.width
                spacing: Style.space(2)

                Text {
                  text: "SCORE"
                  color: root.lcdTextMuted
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  font.bold: true
                }

                Text {
                  text: Game.formatDigits(root.game.score, 6)
                  color: root.lcdTextDark
                  font.family: "monospace"
                  font.pixelSize: Style.font.title
                  font.bold: true
                }
              }

              // HI-SCORE Box
              Column {
                width: parent.width
                spacing: Style.space(2)

                Text {
                  text: "HI-SCORE"
                  color: root.lcdTextMuted
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  font.bold: true
                }

                Text {
                  text: Game.formatDigits(root.bestScore, 6)
                  color: root.classicLcdColors ? root.lcdTextDark : Color.accent
                  font.family: "monospace"
                  font.pixelSize: Style.font.title
                  font.bold: true
                }
              }

              // SPEED & CARS Row
              Row {
                width: parent.width
                spacing: Style.space(16)

                Column {
                  spacing: Style.space(2)
                  Text {
                    text: "SPEED"
                    color: root.lcdTextMuted
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    font.bold: true
                  }
                  Text {
                    text: root.game.level
                    color: root.lcdTextDark
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.title
                    font.bold: true
                  }
                }

                Column {
                  spacing: Style.space(2)
                  Text {
                    text: "CARS"
                    color: root.lcdTextMuted
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    font.bold: true
                  }
                  Text {
                    text: root.game.carsPassed
                    color: root.lcdTextDark
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.title
                    font.bold: true
                  }
                }
              }

              Item { height: Style.space(4); width: 1 }

              // Segmented LCD BOOST / NITRO Gauge
              Column {
                width: parent.width - Style.space(8)
                spacing: Style.space(4)

                Row {
                  width: parent.width
                  Item { width: 1; height: 1 }
                  Text {
                    text: "BOOST"
                    color: root.game.turbo ? (root.classicLcdColors ? "#162010" : Color.accent) : root.lcdTextMuted
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    font.bold: true
                  }
                  Item { width: Style.space(4); height: 1 }
                  Text {
                    text: Math.round(root.game.boost) + "%"
                    color: root.game.boost > 0 ? root.lcdTextDark : Color.muted
                    font.family: "monospace"
                    font.pixelSize: Style.font.caption
                    font.bold: true
                  }
                }

                // 10-bar segmented LCD meter
                Row {
                  spacing: Style.space(2)

                  Repeater {
                    model: 10

                    Rectangle {
                      required property int index
                      width: Style.space(11)
                      height: Style.space(10)
                      radius: 0.5
                      readonly property bool active: (index + 1) * 10 <= root.game.boost
                      color: active
                        ? (root.game.turbo
                           ? (root.classicLcdColors ? "#162010" : Color.accent)
                           : (root.classicLcdColors ? "#293818" : root.foreground))
                        : root.lcdGhostPixel

                      Rectangle {
                        anchors.fill: parent
                        anchors.margins: 1
                        color: "transparent"
                        border.width: 1
                        border.color: parent.active
                          ? (root.classicLcdColors ? "#3b4f23" : Qt.rgba(1, 1, 1, 0.2))
                          : "transparent"
                      }
                    }
                  }
                }
              }

              // Mini Pixel Car Status Indicator
              Item {
                width: parent.width
                height: Style.space(46)

                Grid {
                  anchors.centerIn: parent
                  columns: 3
                  rows: 4
                  spacing: 2

                  Repeater {
                    model: [
                      0, 1, 0,
                      1, 1, 1,
                      0, 1, 0,
                      1, 1, 1
                    ]
                    Rectangle {
                      required property int modelData
                      width: Style.space(6)
                      height: Style.space(6)
                      radius: 0.5
                      color: modelData === 1 ? root.lcdLitPixel : root.lcdGhostPixel
                    }
                  }
                }
              }
            }
          }
        }

        // Bottom Touch / Mouse arcade controls
        Item {
          width: parent.width
          height: Style.space(42)

          Row {
            anchors.centerIn: parent
            spacing: Style.space(10)

            // Left Lane Button
            Rectangle {
              width: Style.space(84)
              height: Style.space(38)
              radius: Style.cornerRadius
              color: root.game.playerLane === Game.LANE_LEFT ? Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.12) : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.05)
              border.width: 1
              border.color: root.game.playerLane === Game.LANE_LEFT ? Color.accent : Color.popups.border

              Text {
                anchors.centerIn: parent
                text: "◄ LEFT"
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
              }

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  keyCatcher.forceActiveFocus()
                  root.steer(Game.LANE_LEFT)
                }
              }
            }

            // BOOST Button (press & hold or click)
            Rectangle {
              id: turboButton
              width: Style.space(104)
              height: Style.space(38)
              radius: Style.cornerRadius
              opacity: root.game.boost > 0 ? 1.0 : 0.5
              color: root.game.turbo ? Color.accent : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.05)
              border.width: 1
              border.color: root.game.turbo ? Color.accent : Color.popups.border

              Row {
                anchors.centerIn: parent
                spacing: Style.space(4)
                Text {
                  text: "󰓅"
                  color: root.game.turbo ? Color.background : root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.bodySmall
                }
                Text {
                  text: "BOOST " + Math.round(root.game.boost) + "%"
                  color: root.game.turbo ? Color.background : root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  font.bold: true
                }
              }

              MouseArea {
                anchors.fill: parent
                cursorShape: root.game.boost > 0 ? Qt.PointingHandCursor : Qt.ForbiddenCursor
                onPressed: {
                  keyCatcher.forceActiveFocus()
                  root.setTurbo(true)
                }
                onReleased: {
                  root.setTurbo(false)
                }
                onCanceled: {
                  root.setTurbo(false)
                }
              }
            }

            // Right Lane Button
            Rectangle {
              width: Style.space(84)
              height: Style.space(38)
              radius: Style.cornerRadius
              color: root.game.playerLane === Game.LANE_RIGHT ? Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.12) : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.05)
              border.width: 1
              border.color: root.game.playerLane === Game.LANE_RIGHT ? Color.accent : Color.popups.border

              Text {
                anchors.centerIn: parent
                text: "RIGHT ►"
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
              }

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  keyCatcher.forceActiveFocus()
                  root.steer(Game.LANE_RIGHT)
                }
              }
            }
          }
        }

        // Keyboard hints footer mentioning both A/D and Arrow keys in English
        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          text: "A / D or ← / → : Lane  ·  W / ↑ : Boost  ·  Space : Pause"
          color: Color.muted
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
        }
      }
    }
  }
}
