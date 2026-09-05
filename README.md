# OmaBrickRace — 9999-in-1 LCD Brick Racing Game for Omarchy

A faithful retro LCD brick racing game and status bar widget for Omarchy, powered by Quickshell, replicating the iconic handheld consoles of the 90s.

> **Disclaimer:** This project is an independent, fan-made clone created from scratch for educational and entertainment purposes.
> - It is not affiliated with, endorsed by, or associated with any original manufacturers of vintage handheld "Brick Game" or "9999-in-1" consoles.
> - All game mechanics are written entirely from scratch and do not use any copyrighted source code, proprietary ROMs, or trademarked assets.

<p align="center">
  <img src="preview.png" alt="OmaBrickRace Preview" />
</p>

## Benefits

- **Retro Handheld Nostalgia in Your Bar**: Enjoy the timeless 90s handheld LCD brick racing experience instantly with a single click right from the Omarchy status bar.
- **Native & Lightweight Performance**: Fast, zero-overhead QML implementation running directly in Quickshell without heavy web runtimes or background battery drain.
- **Authentic 10×20 LCD Dot Matrix**: Faithful physical recreation featuring classic 3×4 brick race cars, scrolling dotted side track borders, and ghost LCD segment backings.
- **Strategic Boost Energy System**: Hold <kbd>W</kbd> or <kbd>↑</kbd> to accelerate to 2.5× turbo speed, draining a dedicated nitro meter that recharges passively over time and earns instant +10% refills for every vehicle successfully dodged.
- **Guaranteed Fair Spawning Algorithm**: Smart lane-spacing calculation guarantees at least one navigable lane opening at any speed, eliminating unavoidable deaths even at levels 8 through 10.
- **Tactile 8-Bit Audio**: Authentic retro piezo-buzzer audio feedback for steering, turbo boost revs, passing cars, crash impacts, and game over sequences.
- **Dual Display Color Modes**: Seamlessly toggle between authentic 90s Olive Green LCD optics and your active Omarchy desktop color theme.
- **State & Preference Persistence**: Automatically saves your high score, sound mute preference, and selected color palette in `~/.local/state/omabrickrace/settings.json`.
- **Complete Ergonomic Controls**: Optimized for tiling window manager users with full Vim keys (<kbd>h</kbd>, <kbd>l</kbd>, <kbd>k</kbd>), WASD, and Arrow keys, plus interactive mouse header shortcuts.
- **Zero Resource Consumption When Idle**: Automatically suspends game loops and rendering timers when the panel is closed or unfocused.
- **Scriptable IPC Automation**: Fully controllable through the Omarchy IPC interface for custom shell shortcuts and window manager keybindings.

---

## Features

- **Matrix & Rendering Engine**:
  - Exact **10 columns by 20 rows** dot-matrix LCD playing field.
  - Authentic **3×4 brick race cars** with distinctive wheel blocks and cockpit center.
  - Animated alternating dotted track borders that give the illusion of scrolling asphalt.
  - Inactive "ghost" pixel cells rendered in low contrast to mimic unlit passive-matrix liquid crystal displays.
  - Prominent in-game state overlays (**READY / PRESS START**, **PAUSED**, **GAME OVER**).

- **Dynamic Boost & Energy System**:
  - Accelerates gameplay speed to **2.5× normal tick rate** for intense thrills and double score accumulation.
  - Dedicated 10-block graphical LCD boost meter with live numeric percentage readout (0% to 100%).
  - Smooth drain rate while boosting (~4.5 seconds of continuous top-speed boost).
  - Balanced recharge mechanics:
    - **+10% instant refill** for every enemy car successfully overtaken.
    - Continuous passive trickle recharge while cruising at normal speeds.
  - Depletion lock preventing jittery re-activation until the player releases the boost key.

- **Speed Progression & Safe Spawning**:
  - **10 escalating speed levels** that dynamically ramp up car spawn frequencies and road velocity.
  - High-speed safety algorithm tracks trailing enemy cars to ensure a lane switch opening is always physically traversable before spawning new obstacles.

- **Audio & Sound Effects**:
  - Synthesized 8-bit PCM audio effects tuned to retro handheld piezo buzzer characteristics:
    - `steer.wav`: Quick pitch tick when changing lanes.
    - `turbo.wav`: High-energy rising frequency chirp when engaging turbo boost.
    - `score.wav`: Satisfying chime when crossing an enemy car.
    - `crash.wav`: Harsh noise impact burst upon collision.
    - `start.wav`: Triple-beep countdown sequence on game start.
    - `gameover.wav`: Classic descending game-over tone.
  - Instant one-click sound toggle via the header speaker button or <kbd>M</kbd> shortcut.

- **Display Themes**:
  - **Classic LCD Green**: Authentic olive-green backlight with high-contrast charcoal segments.
  - **Theme Adaptive**: Harmonizes with your current Omarchy color palette, background blur, and border styles.

---

## Requirements

- **Omarchy Linux**: Quickshell-powered desktop shell with third-party plugin support.
- **Qt Quick & Multimedia**: `qt6-declarative` and `qt6-multimedia` (standard dependencies in Omarchy).
- **Nerd Font**: Any Nerd Font (e.g., `JetBrainsMono Nerd Font`, default in Omarchy) for header iconography.

---

## Installation

Install and enable the plugin directly from GitHub using the Omarchy plugin manager:

```bash
omarchy plugin add https://github.com/asdfsnlr/omabrickrace.git --enable --section left
```

Or clone and enable locally for development:

```bash
mkdir -p ~/.config/omarchy/plugins
cp -r "$PWD" ~/.config/omarchy/plugins/omabrickrace
omarchy plugin enable omabrickrace --section left
```

To update the plugin to the latest version:

```bash
omarchy plugin update omabrickrace
```

---

## Removal

To disable or remove the plugin from Omarchy:

```bash
# Disable without uninstalling
omarchy plugin disable omabrickrace

# Remove the plugin completely
omarchy plugin remove omabrickrace
```

Or remove manually if installed locally:

```bash
omarchy plugin disable omabrickrace
rm -rf ~/.config/omarchy/plugins/omabrickrace
```

---

## Configuration & Settings

OmaBrickRace automatically maintains persistent settings across sessions in:

```
~/.local/state/omabrickrace/settings.json
```

```json
{
  "version": 1,
  "soundEnabled": true,
  "classicLcdColors": true,
  "bestScore": 1250
}
```

### Manifest Settings Schema

The plugin exposes standard bar-widget settings defined in `manifest.json`:

| Option | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `soundEnabled` | boolean | `true` | Enable or mute retro 8-bit sound effects |
| `classicLcdColors` | boolean | `true` | Use authentic olive green LCD colorway instead of Omarchy theme |
| `bestScore` | integer | `0` | All-time personal high score |

### Adding to Status Bar Layout

You can place `omabrickrace` in your preferred section (`left`, `center`, or `right`) in `~/.config/omarchy/shell.json`:

```json
{
  "bar": {
    "layout": {
      "left": [
        "omabrickrace"
      ]
    }
  }
}
```

---

## Controls & Gameplay

### Keyboard Shortcuts

| Key | Alternate Keys | Action |
| :--- | :--- | :--- |
| <kbd>←</kbd> | <kbd>A</kbd>, <kbd>H</kbd> | Steer car to Left Lane |
| <kbd>→</kbd> | <kbd>D</kbd>, <kbd>L</kbd> | Steer car to Right Lane |
| <kbd>↑</kbd> *(Hold)* | <kbd>W</kbd>, <kbd>K</kbd> | Turbo Boost (2.5× Speed) |
| <kbd>Space</kbd> | <kbd>Return</kbd> | Start Game / Pause / Resume |
| <kbd>P</kbd> | — | Toggle Pause / Resume |
| <kbd>R</kbd> | — | Restart Game (even while paused) |
| <kbd>M</kbd> | — | Mute / Unmute 8-Bit Audio |
| <kbd>C</kbd> | — | Toggle Classic LCD Green / Theme Palette |
| <kbd>Esc</kbd> | — | Close Game Panel |

### Header Interactive Actions

- **Icon**: OmaBrickRace 3×4 mini-car logo.
- **󰕾 / 󰝟 (Speaker)**: Click to toggle sound on/off.
- **󰏘 (Palette)**: Click to toggle between LCD Olive Green and active Omarchy theme colors.
- **󰐊 / 󰏤 (Play/Pause)**: Click to start, pause, or resume the game.
- **󰑐 (Restart)**: Click to reset and start a fresh race.

---

## IPC Controls & Automation

You can control OmaBrickRace programmatically or bind shortcuts in your window manager (`hyprland.conf`) via Quickshell IPC:

```bash
# Toggle the game panel open/closed
quickshell -p /usr/share/omarchy/shell ipc call omabrickrace toggle

# Open the game panel
quickshell -p /usr/share/omarchy/shell ipc call omabrickrace open

# Close the game panel
quickshell -p /usr/share/omarchy/shell ipc call omabrickrace close

# Start or restart a game session
quickshell -p /usr/share/omarchy/shell ipc call omabrickrace restart

# Toggle pause state
quickshell -p /usr/share/omarchy/shell ipc call omabrickrace pause

# Toggle audio mute
quickshell -p /usr/share/omarchy/shell ipc call omabrickrace mute
```

### Example Hyprland Keybinding

Add this to `~/.config/hypr/hyprland.conf` to toggle the game with <kbd>Super</kbd> + <kbd>G</kbd>:

```ini
bind = $mainMod, G, exec, quickshell -p /usr/share/omarchy/shell ipc call omabrickrace toggle
```

---

## Plugin Management

```bash
# List all installed Omarchy plugins and their status
omarchy plugin list

# Validate plugin manifest and schema
omarchy plugin validate ~/.config/omarchy/plugins/omabrickrace

# Restart shell to apply updates
omarchy restart shell
```

---

## License

MIT License. See [LICENSE](LICENSE) for details.
